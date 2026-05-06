begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

-- ============================================================
-- Setup: two test users, exchange rate already seeded by migration
-- ============================================================
INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a@test.com'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@test.com');

-- Create wallets (carry-over balances from prior months)
INSERT INTO public.reward_wallets (user_id, balance) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 8),    -- 8 pts = 400 JPY
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 0);

-- Add reward_ledger entries:
--   user A: 8 pts of carry-over (created_at = last month, NOT counted in MtD)
INSERT INTO public.reward_ledger (user_id, amount, reason, created_at)
VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 8, 'review_completed',
    (now() AT TIME ZONE 'Asia/Tokyo' - INTERVAL '40 days') AT TIME ZONE 'Asia/Tokyo'
);

-- Add MtD earnings: user A earns 30 pts this month, user B earns 10 pts this month
INSERT INTO public.reward_ledger (user_id, amount, reason, created_at)
VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 30, 'review_completed', now()),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 10, 'evidence_timeout', now());

-- Update wallets to reflect new earnings (in real flow, grant_reward does both)
UPDATE public.reward_wallets SET balance = 38 WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
UPDATE public.reward_wallets SET balance = 10 WHERE user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

-- ============================================================
-- Test 1: Function returns expected currency and rate
-- ============================================================
SELECT is(
    (SELECT public.get_payout_topup_metrics('JPY')->>'currency'),
    'JPY',
    'Currency is JPY'
);

SELECT is(
    (SELECT (public.get_payout_topup_metrics('JPY')->>'rate_per_point')::integer),
    50,
    'rate_per_point is 50 (seeded)'
);

-- ============================================================
-- Test 2: total_obligation_jpy = (8 + 30 + 10) * 50 = 2400
-- ============================================================
SELECT is(
    (SELECT (public.get_payout_topup_metrics('JPY')->>'total_obligation_jpy')::numeric),
    2400::numeric,
    'total_obligation_jpy = sum(wallet.balance) * rate'
);

-- ============================================================
-- Test 3: month_to_date_earnings_jpy = (30 + 10) * 50 = 2000
--   (carry-over entry from 40 days ago is excluded)
-- ============================================================
SELECT is(
    (SELECT (public.get_payout_topup_metrics('JPY')->>'month_to_date_earnings_jpy')::numeric),
    2000::numeric,
    'month_to_date_earnings_jpy excludes prior-month entries'
);

-- ============================================================
-- Test 4: buffer_multiplier comes from singleton config
-- ============================================================
SELECT is(
    (SELECT (public.get_payout_topup_metrics('JPY')->>'buffer_multiplier')::numeric),
    1.3::numeric,
    'buffer_multiplier = 1.3 (default seeded)'
);

-- ============================================================
-- Test 5: Unknown currency raises an exception
-- ============================================================
SELECT throws_ok(
    $$SELECT public.get_payout_topup_metrics('USD')$$,
    'P0001',  -- raise_exception
    'No active exchange rate for currency: USD',
    'Unknown currency raises exception'
);

select * from finish();
rollback;
