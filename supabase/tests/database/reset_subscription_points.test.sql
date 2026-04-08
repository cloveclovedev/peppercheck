begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- ============================================================
-- Setup: create test user and wallet
-- ============================================================
INSERT INTO auth.users (id, email) VALUES
    ('d1111111-1111-1111-1111-111111111111', 'reset-pt-test@test.com');

-- User gets a point_wallet via handle_new_user trigger (balance=0, locked=0).
-- Set initial state: balance=3, locked=0 (simulating unused points from prior period)
UPDATE public.point_wallets
SET balance = 3
WHERE user_id = 'd1111111-1111-1111-1111-111111111111';

-- ============================================================
-- Test 1: Reset with remaining available points
-- ============================================================
SELECT is(
    (SELECT public.reset_subscription_points(
        'd1111111-1111-1111-1111-111111111111', 5, 'inv-001'
    )),
    true,
    'Test 1: First call returns true (points reset)'
);

SELECT is(
    (SELECT balance FROM public.point_wallets WHERE user_id = 'd1111111-1111-1111-1111-111111111111'),
    5,
    'Test 1: Balance reset to plan amount (5), not 3+5=8'
);

-- Check expiry ledger entry exists with -3
SELECT is(
    (SELECT amount FROM public.point_ledger
     WHERE user_id = 'd1111111-1111-1111-1111-111111111111'
     AND reason = 'plan_renewal_expiry'
     AND description = 'Subscription renewal: inv-001'),
    -3,
    'Test 1: Expiry ledger records -3 forfeited points'
);

-- Check renewal ledger entry exists with +5
SELECT is(
    (SELECT amount FROM public.point_ledger
     WHERE user_id = 'd1111111-1111-1111-1111-111111111111'
     AND reason = 'plan_renewal'
     AND description = 'Subscription renewal: inv-001'),
    5,
    'Test 1: Renewal ledger records +5 granted points'
);

-- ============================================================
-- Test 2: Idempotency — same invoice_id returns false, no change
-- ============================================================
SELECT is(
    (SELECT public.reset_subscription_points(
        'd1111111-1111-1111-1111-111111111111', 5, 'inv-001'
    )),
    false,
    'Test 2: Duplicate invoice_id returns false'
);

SELECT is(
    (SELECT balance FROM public.point_wallets WHERE user_id = 'd1111111-1111-1111-1111-111111111111'),
    5,
    'Test 2: Balance unchanged after duplicate call'
);

-- ============================================================
-- Test 3: Reset with locked points — locked preserved
-- ============================================================
-- Simulate 2 locked points (in-progress match)
UPDATE public.point_wallets
SET balance = 4, locked = 2
WHERE user_id = 'd1111111-1111-1111-1111-111111111111';

SELECT is(
    (SELECT public.reset_subscription_points(
        'd1111111-1111-1111-1111-111111111111', 5, 'inv-002'
    )),
    true,
    'Test 3: Reset with locked points returns true'
);

-- balance = p_amount(5) + locked(2) = 7
SELECT is(
    (SELECT balance FROM public.point_wallets WHERE user_id = 'd1111111-1111-1111-1111-111111111111'),
    7,
    'Test 3: Balance = plan_amount(5) + locked(2) = 7'
);

SELECT is(
    (SELECT locked FROM public.point_wallets WHERE user_id = 'd1111111-1111-1111-1111-111111111111'),
    2,
    'Test 3: Locked points unchanged'
);

-- Expiry should record -(4-2) = -2 (only available points forfeited)
SELECT is(
    (SELECT amount FROM public.point_ledger
     WHERE user_id = 'd1111111-1111-1111-1111-111111111111'
     AND reason = 'plan_renewal_expiry'
     AND description = 'Subscription renewal: inv-002'),
    -2,
    'Test 3: Expiry ledger records -2 (available points only, not locked)'
);

-- ============================================================
-- Test 4: Reset with zero available points — no expiry entry
-- ============================================================
UPDATE public.point_wallets
SET balance = 2, locked = 2
WHERE user_id = 'd1111111-1111-1111-1111-111111111111';

SELECT is(
    (SELECT public.reset_subscription_points(
        'd1111111-1111-1111-1111-111111111111', 5, 'inv-003'
    )),
    true,
    'Test 4: Reset with zero available points returns true'
);

-- No expiry entry for inv-003
SELECT is(
    (SELECT count(*) FROM public.point_ledger
     WHERE user_id = 'd1111111-1111-1111-1111-111111111111'
     AND reason = 'plan_renewal_expiry'
     AND description = 'Subscription renewal: inv-003'),
    0::bigint,
    'Test 4: No expiry ledger entry when available points = 0'
);

select * from finish();
rollback;
