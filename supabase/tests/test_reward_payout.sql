-- =============================================================================
-- Test: Reward Payout System (prepare_monthly_payouts & deduct_reward_for_payout)
--
-- Usage:
--   docker cp supabase/tests/test_reward_payout.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_reward_payout.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Reward Payout System'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Cleaning up existing test data...'

DELETE FROM public.reward_payouts WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
DELETE FROM public.reward_ledger WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
DELETE FROM public.point_ledger WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
DELETE FROM public.stripe_accounts WHERE profile_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
DELETE FROM public.reward_wallets WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
DELETE FROM public.point_wallets WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
DELETE FROM auth.users WHERE id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');

\echo '[Setup] Creating test users...'

-- User 1: Referee WITH Connect account (payouts_enabled=true)
-- User 2: Referee WITHOUT Connect account
-- User 3: User with zero balance (should be ignored)
INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'referee_with_connect@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee_no_connect@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('33333333-3333-3333-3333-333333333333', 'zero_balance@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Creating stripe_accounts for user 1 (Connect enabled)...'

INSERT INTO public.stripe_accounts (profile_id, stripe_connect_account_id, payouts_enabled)
VALUES ('11111111-1111-1111-1111-111111111111', 'acct_test_111', true);

\echo '[Setup] Creating reward wallets with balances...'

-- reward_wallets are created on-demand by grant_reward(), not by auth trigger.
-- Insert directly for test setup.
INSERT INTO public.reward_wallets (user_id, balance)
VALUES
  ('11111111-1111-1111-1111-111111111111', 5),
  ('22222222-2222-2222-2222-222222222222', 3)
ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance;
-- User 3 has no wallet (or zero balance) — should be ignored


-- ===== Test 1: Month-end guard =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Month-end guard'
\echo '=========================================='

DO $$
DECLARE
  v_result jsonb;
  v_today date := CURRENT_DATE;
  v_last_day date := (date_trunc('month', CURRENT_DATE) + interval '1 month' - interval '1 day')::date;
BEGIN
  v_result := public.prepare_monthly_payouts('JPY');

  IF v_today = v_last_day THEN
    -- Today IS the last day — guard should NOT trigger, function runs normally
    ASSERT (v_result->>'skipped') IS DISTINCT FROM 'true'
        OR (v_result->>'reason') IS DISTINCT FROM 'Not last day of month',
      'Test 1 FAILED: should not skip due to guard on last day of month';
    RAISE NOTICE 'Test 1 PASSED: guard did not block (today is last day of month)';
  ELSE
    -- Today is NOT the last day — guard should trigger
    ASSERT (v_result->>'skipped')::boolean = true,
      'Test 1 FAILED: should be skipped on non-last day';
    ASSERT v_result->>'reason' = 'Not last day of month',
      'Test 1 FAILED: reason should be "Not last day of month"';
    RAISE NOTICE 'Test 1 PASSED: guard blocks execution on non-last day (%)' , v_today;
  END IF;
END $$;

-- Clean up any records created if today happens to be the last day
DELETE FROM public.reward_payouts;


-- ===== Override function to bypass guard for core logic tests =====
\echo ''
\echo '[Setup] Overriding prepare_monthly_payouts to bypass month-end guard...'

CREATE OR REPLACE FUNCTION public.prepare_monthly_payouts(
    p_currency text DEFAULT 'JPY'
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $fn$
DECLARE
    v_rate integer;
    v_batch_date date := CURRENT_DATE;
    v_wallet RECORD;
    v_pending_count integer := 0;
    v_skipped_count integer := 0;
    v_connect_account_id text;
    v_payouts_enabled boolean;
BEGIN
    -- [GUARD REMOVED FOR TESTING]

    SELECT rate_per_point INTO v_rate
    FROM public.reward_exchange_rates
    WHERE currency = p_currency AND active = true;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'No active exchange rate for currency: %', p_currency;
    END IF;

    IF EXISTS (SELECT 1 FROM public.reward_payouts WHERE batch_date = v_batch_date AND currency = p_currency LIMIT 1) THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'Payouts already prepared for ' || v_batch_date);
    END IF;

    FOR v_wallet IN
        SELECT user_id, balance FROM public.reward_wallets WHERE balance > 0
    LOOP
        SELECT sa.stripe_connect_account_id, sa.payouts_enabled
        INTO v_connect_account_id, v_payouts_enabled
        FROM public.stripe_accounts sa
        WHERE sa.profile_id = v_wallet.user_id;

        IF v_connect_account_id IS NOT NULL AND v_payouts_enabled = true THEN
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'pending', v_batch_date
            );
            v_pending_count := v_pending_count + 1;
        ELSE
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date, error_message
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'skipped', v_batch_date,
                'Connect account not ready (payouts_enabled=false or no account)'
            );
            v_skipped_count := v_skipped_count + 1;

            PERFORM public.notify_event(
                v_wallet.user_id,
                'notification_payout_connect_required',
                NULL,
                jsonb_build_object('batch_date', v_batch_date)
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'pending', v_pending_count,
        'skipped', v_skipped_count,
        'batch_date', v_batch_date,
        'currency', p_currency,
        'rate_per_point', v_rate
    );
END;
$fn$;


-- ===== Test 2: Exchange rate seed data exists =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Exchange rate seed data'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT rate_per_point FROM public.reward_exchange_rates WHERE currency = 'JPY' AND active = true) = 50,
    'Test 2 FAILED: JPY rate_per_point should be 50';
  RAISE NOTICE 'Test 2 PASSED: JPY exchange rate = 50 per point';
END $$;


-- ===== Test 3: prepare creates pending for Connect-enabled user =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Pending for Connect-enabled user'
\echo '=========================================='

SELECT public.prepare_monthly_payouts('JPY');

DO $$
BEGIN
  ASSERT (SELECT status FROM public.reward_payouts WHERE user_id = '11111111-1111-1111-1111-111111111111') = 'pending',
    'Test 3 FAILED: should be pending for user with Connect';
  RAISE NOTICE 'Test 3 PASSED: pending record created for Connect-enabled user';
END $$;


-- ===== Test 4: prepare creates skipped for user without Connect =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Skipped for user without Connect'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT status FROM public.reward_payouts WHERE user_id = '22222222-2222-2222-2222-222222222222') = 'skipped',
    'Test 4 FAILED: should be skipped for user without Connect';
  ASSERT (SELECT error_message FROM public.reward_payouts WHERE user_id = '22222222-2222-2222-2222-222222222222') IS NOT NULL,
    'Test 4 FAILED: error_message should be set for skipped records';
  RAISE NOTICE 'Test 4 PASSED: skipped record created for user without Connect';
END $$;


-- ===== Test 5: Zero-balance users are not included =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Zero-balance users ignored'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT COUNT(*) FROM public.reward_payouts WHERE user_id = '33333333-3333-3333-3333-333333333333') = 0,
    'Test 5 FAILED: zero-balance user should not have a payout record';
  ASSERT (SELECT COUNT(*) FROM public.reward_payouts) = 2,
    'Test 5 FAILED: total payout records should be 2';
  RAISE NOTICE 'Test 5 PASSED: zero-balance user correctly ignored';
END $$;


-- ===== Test 6: Currency amount calculated correctly =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Currency amount calculation'
\echo '=========================================='

DO $$
BEGIN
  -- User 1: 5 points * 50 JPY/point = 250 JPY
  ASSERT (SELECT currency_amount FROM public.reward_payouts WHERE user_id = '11111111-1111-1111-1111-111111111111') = 250,
    'Test 6 FAILED: currency_amount should be 250 (5 points * 50)';
  ASSERT (SELECT points_amount FROM public.reward_payouts WHERE user_id = '11111111-1111-1111-1111-111111111111') = 5,
    'Test 6 FAILED: points_amount should be 5';
  ASSERT (SELECT rate_per_point FROM public.reward_payouts WHERE user_id = '11111111-1111-1111-1111-111111111111') = 50,
    'Test 6 FAILED: rate_per_point snapshot should be 50';
  -- User 2: 3 points * 50 JPY/point = 150 JPY
  ASSERT (SELECT currency_amount FROM public.reward_payouts WHERE user_id = '22222222-2222-2222-2222-222222222222') = 150,
    'Test 6 FAILED: currency_amount should be 150 (3 points * 50)';
  RAISE NOTICE 'Test 6 PASSED: currency_amount = balance * rate_per_point';
END $$;


-- ===== Test 7: Idempotency — second call returns skipped =====
\echo ''
\echo '=========================================='
\echo ' Test 7: Idempotency check'
\echo '=========================================='

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.prepare_monthly_payouts('JPY');
  ASSERT (v_result->>'skipped')::boolean = true,
    'Test 7 FAILED: second call should return skipped';
  ASSERT v_result->>'reason' LIKE 'Payouts already prepared%',
    'Test 7 FAILED: reason should indicate already prepared';
  -- Record count should not change
  ASSERT (SELECT COUNT(*) FROM public.reward_payouts) = 2,
    'Test 7 FAILED: no new records should be created';
  RAISE NOTICE 'Test 7 PASSED: idempotency prevents duplicate payout records';
END $$;


-- ===== Test 8: deduct_reward_for_payout deducts balance =====
\echo ''
\echo '=========================================='
\echo ' Test 8: deduct_reward_for_payout success'
\echo '=========================================='

DO $$
DECLARE
  v_payout_id uuid;
BEGIN
  SELECT id INTO v_payout_id FROM public.reward_payouts
    WHERE user_id = '11111111-1111-1111-1111-111111111111';

  PERFORM public.deduct_reward_for_payout(
    '11111111-1111-1111-1111-111111111111',
    5,
    v_payout_id
  );

  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 8 FAILED: balance should be 0 after deducting 5';
  RAISE NOTICE 'Test 8 PASSED: wallet balance deducted correctly';
END $$;


-- ===== Test 9: deduct creates payout ledger entry =====
\echo ''
\echo '=========================================='
\echo ' Test 9: Payout ledger entry'
\echo '=========================================='

DO $$
DECLARE
  v_payout_id uuid;
BEGIN
  SELECT id INTO v_payout_id FROM public.reward_payouts
    WHERE user_id = '11111111-1111-1111-1111-111111111111';

  ASSERT (SELECT COUNT(*) FROM public.reward_ledger
    WHERE user_id = '11111111-1111-1111-1111-111111111111'
    AND reason = 'payout'
    AND amount = -5
    AND related_id = v_payout_id) = 1,
    'Test 9 FAILED: should have exactly 1 payout ledger entry with amount=-5';
  RAISE NOTICE 'Test 9 PASSED: ledger entry created (reason=payout, amount=-5)';
END $$;


-- ===== Test 10: deduct fails on insufficient balance =====
\echo ''
\echo '=========================================='
\echo ' Test 10: Insufficient balance error'
\echo '=========================================='

DO $$
DECLARE
  v_payout_id uuid;
BEGIN
  SELECT id INTO v_payout_id FROM public.reward_payouts
    WHERE user_id = '11111111-1111-1111-1111-111111111111';

  -- Balance is now 0, trying to deduct 1 should fail
  PERFORM public.deduct_reward_for_payout(
    '11111111-1111-1111-1111-111111111111',
    1,
    v_payout_id
  );
  RAISE NOTICE 'Test 10 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Insufficient reward balance%' THEN
      RAISE NOTICE 'Test 10 PASSED: insufficient balance error raised correctly';
    ELSE
      RAISE NOTICE 'Test 10 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 11: No exchange rate raises exception =====
\echo ''
\echo '=========================================='
\echo ' Test 11: Missing exchange rate error'
\echo '=========================================='

DO $$
BEGIN
  PERFORM public.prepare_monthly_payouts('USD');
  RAISE NOTICE 'Test 11 FAILED: should have raised exception for USD';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'No active exchange rate for currency%' THEN
      RAISE NOTICE 'Test 11 PASSED: missing exchange rate raises exception';
    ELSE
      RAISE NOTICE 'Test 11 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Cleanup =====
\echo ''
\echo '=========================================='
\echo ' Cleanup'
\echo '=========================================='

ROLLBACK;

\echo 'All test data rolled back (including function override).'
\echo ''
\echo '=========================================='
\echo ' All tests complete!'
\echo '=========================================='
