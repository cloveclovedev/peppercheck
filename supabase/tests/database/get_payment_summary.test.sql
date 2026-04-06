begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- ============================================================
-- Setup: create test user
-- ============================================================
INSERT INTO auth.users (id, email) VALUES
    ('a1111111-1111-1111-1111-111111111111', 'testuser@test.com');

-- Deactivate the trial wallet auto-created by handle_new_user trigger
-- so Test 1's trial_points=NULL assertion holds
UPDATE public.trial_point_wallets SET is_active = false WHERE user_id = 'a1111111-1111-1111-1111-111111111111';

-- Set JWT claims to simulate authenticated user
SELECT set_config('request.jwt.claims', '{"sub": "a1111111-1111-1111-1111-111111111111"}', true);

-- ============================================================
-- Test 1: New user with no data — points default to zero
-- ============================================================
SELECT is(
    (SELECT (public.get_payment_summary()->'points'->>'balance')::integer),
    0,
    'Test 1: New user has 0 point balance'
);

SELECT is(
    (SELECT public.get_payment_summary()->>'trial_points'),
    NULL::text,
    'Test 1: New user has null trial_points'
);

SELECT is(
    (SELECT (public.get_payment_summary()->>'obligations_remaining')::integer),
    0,
    'Test 1: New user has 0 obligations'
);

SELECT is(
    (SELECT public.get_payment_summary()->>'rewards'),
    NULL::text,
    'Test 1: New user has null rewards'
);

-- ============================================================
-- Setup: add point wallet with locked points
-- ============================================================
INSERT INTO public.point_wallets (user_id, balance, locked)
VALUES ('a1111111-1111-1111-1111-111111111111', 10, 3)
ON CONFLICT (user_id) DO UPDATE SET balance = 10, locked = 3;

-- ============================================================
-- Test 2: Points with locked amount
-- ============================================================
SELECT is(
    (SELECT (public.get_payment_summary()->'points'->>'balance')::integer),
    10,
    'Test 2: Point balance is 10'
);

SELECT is(
    (SELECT (public.get_payment_summary()->'points'->>'available')::integer),
    7,
    'Test 2: Available points is 7 (10 - 3)'
);

-- ============================================================
-- Setup: add active trial point wallet
-- ============================================================
INSERT INTO public.trial_point_wallets (user_id, balance, locked, is_active)
VALUES ('a1111111-1111-1111-1111-111111111111', 3, 1, true)
ON CONFLICT (user_id) DO UPDATE SET balance = 3, locked = 1, is_active = true;

-- ============================================================
-- Test 3: Active trial points are returned
-- ============================================================
SELECT is(
    (SELECT (public.get_payment_summary()->'trial_points'->>'available')::integer),
    2,
    'Test 3: Trial points available is 2 (3 - 1)'
);

-- ============================================================
-- Setup: deactivate trial points (simulates subscription start)
-- ============================================================
UPDATE public.trial_point_wallets
SET is_active = false
WHERE user_id = 'a1111111-1111-1111-1111-111111111111';

-- ============================================================
-- Test 4: Deactivated trial points return null
-- ============================================================
SELECT is(
    (SELECT public.get_payment_summary()->>'trial_points'),
    NULL::text,
    'Test 4: Deactivated trial points return null'
);

-- ============================================================
-- Setup: create prerequisite task + referee requests for obligations FK
-- ============================================================
INSERT INTO public.tasks (id, tasker_id, title, due_date, status) VALUES
    ('c3333333-3333-3333-3333-333333333333',
     'a1111111-1111-1111-1111-111111111111',
     'Test Task for Obligations',
     NOW() + INTERVAL '7 days',
     'open');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status) VALUES
    ('d4444444-4444-4444-4444-444444444444', 'c3333333-3333-3333-3333-333333333333', 'standard', 'matched'),
    ('d5555555-5555-5555-5555-555555555555', 'c3333333-3333-3333-3333-333333333333', 'standard', 'matched'),
    ('d6666666-6666-6666-6666-666666666666', 'c3333333-3333-3333-3333-333333333333', 'standard', 'matched');

-- ============================================================
-- Setup: add pending referee obligations
-- (These should survive trial point deactivation)
-- ============================================================
INSERT INTO public.referee_obligations (id, user_id, status, source_request_id)
VALUES
    (gen_random_uuid(), 'a1111111-1111-1111-1111-111111111111', 'pending', 'd4444444-4444-4444-4444-444444444444'),
    (gen_random_uuid(), 'a1111111-1111-1111-1111-111111111111', 'pending', 'd5555555-5555-5555-5555-555555555555'),
    (gen_random_uuid(), 'a1111111-1111-1111-1111-111111111111', 'fulfilled', 'd6666666-6666-6666-6666-666666666666');

-- ============================================================
-- Test 5: Obligations count only pending (not fulfilled), independent of trial points
-- ============================================================
SELECT is(
    (SELECT (public.get_payment_summary()->>'obligations_remaining')::integer),
    2,
    'Test 5: obligations_remaining is 2 (only pending, not fulfilled)'
);

-- ============================================================
-- Setup: add reward wallet and ensure exchange rate exists
-- ============================================================
INSERT INTO public.reward_wallets (user_id, balance)
VALUES ('a1111111-1111-1111-1111-111111111111', 8)
ON CONFLICT (user_id) DO UPDATE SET balance = 8;

-- Ensure JPY exchange rate exists (seed data should have this)
INSERT INTO public.reward_exchange_rates (currency, rate_per_point, active)
VALUES ('JPY', 50, true)
ON CONFLICT (currency) DO UPDATE SET rate_per_point = 50, active = true;

-- ============================================================
-- Test 6: Rewards with currency conversion
-- ============================================================
SELECT is(
    (SELECT (public.get_payment_summary()->'rewards'->>'amount_minor')::integer),
    400,
    'Test 6: Reward amount_minor is 400 (8 points × 50 rate)'
);

SELECT is(
    (SELECT public.get_payment_summary()->'rewards'->>'currency_code'),
    'JPY',
    'Test 6: Reward currency is JPY'
);

-- ============================================================
-- Setup: add payout history
-- ============================================================
INSERT INTO public.reward_payouts (id, user_id, points_amount, currency, currency_amount, rate_per_point, status, batch_date, created_at)
VALUES
    (gen_random_uuid(), 'a1111111-1111-1111-1111-111111111111', 10, 'JPY', 500, 50, 'success', '2026-02-28', '2026-02-28 15:00:00'),
    (gen_random_uuid(), 'a1111111-1111-1111-1111-111111111111', 20, 'JPY', 1000, 50, 'success', '2026-03-31', '2026-03-31 15:00:00'),
    (gen_random_uuid(), 'a1111111-1111-1111-1111-111111111111', 5, 'JPY', 250, 50, 'failed', '2026-03-31', '2026-03-31 16:00:00');

-- ============================================================
-- Test 7: Total earned only counts successful payouts
-- ============================================================
SELECT is(
    (SELECT (public.get_payment_summary()->>'total_earned_minor')::integer),
    1500,
    'Test 7: total_earned_minor is 1500 (500 + 1000, excludes failed)'
);

-- ============================================================
-- Test 8: Recent payout is the most recent by created_at
-- ============================================================
SELECT is(
    (SELECT public.get_payment_summary()->'recent_payout'->>'status'),
    'failed',
    'Test 8: recent_payout is the latest record (failed, created at 16:00)'
);

-- ============================================================
-- Test 9: next_payout_date is last day of current month
-- ============================================================
SELECT is(
    (SELECT (public.get_payment_summary()->>'next_payout_date')::date),
    (date_trunc('month', now()) + interval '1 month - 1 day')::date,
    'Test 9: next_payout_date is last day of current month'
);

-- ============================================================
-- Test 10: total_earned_currency matches active exchange rate
-- ============================================================
SELECT is(
    (SELECT public.get_payment_summary()->>'total_earned_currency'),
    'JPY',
    'Test 10: total_earned_currency is JPY'
);

select * from finish();
rollback;
