-- =============================================================================
-- Test: Trial Point Functions
--
-- Usage:
--   docker cp supabase/tests/test_trial_points.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_trial_points.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Trial Point Functions'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Inserting trial_point_config...'

-- Ensure singleton config row exists with initial_grant_amount = 3
INSERT INTO public.trial_point_config (id, initial_grant_amount)
VALUES (true, 3)
ON CONFLICT (id) DO UPDATE SET initial_grant_amount = 3;

\echo '[Setup] Creating test users (triggers handle_new_user)...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('aaaa0001-0000-0000-0000-000000000000', 'trial_tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('aaaa0002-0000-0000-0000-000000000000', 'trial_referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Creating task...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('bbbb0001-0000-0000-0000-000000000000', 'aaaa0001-0000-0000-0000-000000000000', 'Trial Test Task', 'Test description', 'Test criteria', now() + interval '7 days', 'open');

\echo '[Setup] Creating referee request...'

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source)
VALUES ('cccc0001-0000-0000-0000-000000000000', 'bbbb0001-0000-0000-0000-000000000000', 'standard', 'accepted', 'aaaa0002-0000-0000-0000-000000000000', now(), 'trial'::public.point_source_type);


-- ===== Test 1: handle_new_user creates trial wallet with balance=3 =====
\echo ''
\echo '=========================================='
\echo ' Test 1: handle_new_user creates trial wallet'
\echo '=========================================='

DO $$
DECLARE
  v_balance integer;
  v_locked  integer;
  v_is_active boolean;
  v_ledger_count integer;
BEGIN
  SELECT balance, locked, is_active
  INTO v_balance, v_locked, v_is_active
  FROM public.trial_point_wallets
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000';

  ASSERT v_balance = 3,
    format('Test 1 FAILED: expected balance=3, got %s', v_balance);
  ASSERT v_locked = 0,
    format('Test 1 FAILED: expected locked=0, got %s', v_locked);
  ASSERT v_is_active = true,
    'Test 1 FAILED: wallet should be active';

  SELECT COUNT(*) INTO v_ledger_count
  FROM public.trial_point_ledger
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000'
    AND reason = 'initial_grant';

  ASSERT v_ledger_count = 1,
    format('Test 1 FAILED: expected 1 initial_grant ledger entry, got %s', v_ledger_count);

  RAISE NOTICE 'Test 1 PASSED: trial wallet created with balance=3 and initial_grant ledger entry';
END $$;


-- ===== Test 2: lock_trial_points works (balance stays 3, locked becomes 1) =====
\echo ''
\echo '=========================================='
\echo ' Test 2: lock_trial_points'
\echo '=========================================='

SELECT public.lock_trial_points(
  'aaaa0001-0000-0000-0000-000000000000',
  1,
  'matching_lock'::public.trial_point_reason,
  'Lock for matching',
  'cccc0001-0000-0000-0000-000000000000'
);

DO $$
DECLARE
  v_balance integer;
  v_locked  integer;
  v_ledger_amount integer;
BEGIN
  SELECT balance, locked INTO v_balance, v_locked
  FROM public.trial_point_wallets
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000';

  ASSERT v_balance = 3,
    format('Test 2 FAILED: balance should remain 3, got %s', v_balance);
  ASSERT v_locked = 1,
    format('Test 2 FAILED: locked should be 1, got %s', v_locked);

  SELECT amount INTO v_ledger_amount
  FROM public.trial_point_ledger
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000'
    AND reason = 'matching_lock'
  ORDER BY created_at DESC
  LIMIT 1;

  ASSERT v_ledger_amount = -1,
    format('Test 2 FAILED: ledger entry amount should be -1, got %s', v_ledger_amount);

  RAISE NOTICE 'Test 2 PASSED: lock_trial_points works correctly';
END $$;


-- ===== Test 3: lock_trial_points fails with insufficient points =====
\echo ''
\echo '=========================================='
\echo ' Test 3: lock_trial_points fails with insufficient points'
\echo '=========================================='

DO $$
BEGIN
  -- Wallet has balance=3, locked=1, so available=2. Trying to lock 3 should fail.
  PERFORM public.lock_trial_points(
    'aaaa0001-0000-0000-0000-000000000000',
    3,
    'matching_lock'::public.trial_point_reason,
    'Should fail'
  );
  RAISE NOTICE 'Test 3 FAILED: should have raised exception for insufficient points';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE '%Insufficient available trial points%' THEN
      RAISE NOTICE 'Test 3 PASSED: insufficient points correctly rejected (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 3 FAILED: unexpected error: %', SQLERRM;
      RAISE;
    END IF;
END $$;


-- ===== Test 4: consume_trial_points decrements balance+locked and creates obligation =====
\echo ''
\echo '=========================================='
\echo ' Test 4: consume_trial_points'
\echo '=========================================='

SELECT public.consume_trial_points(
  'aaaa0001-0000-0000-0000-000000000000',
  1,
  'matching_settled'::public.trial_point_reason,
  'Settle matching',
  'cccc0001-0000-0000-0000-000000000000'
);

DO $$
DECLARE
  v_balance integer;
  v_locked  integer;
  v_obligation_count integer;
BEGIN
  SELECT balance, locked INTO v_balance, v_locked
  FROM public.trial_point_wallets
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000';

  ASSERT v_balance = 2,
    format('Test 4 FAILED: balance should be 2 after consume, got %s', v_balance);
  ASSERT v_locked = 0,
    format('Test 4 FAILED: locked should be 0 after consume, got %s', v_locked);

  SELECT COUNT(*) INTO v_obligation_count
  FROM public.referee_obligations
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000'
    AND status = 'pending';

  ASSERT v_obligation_count = 1,
    format('Test 4 FAILED: expected 1 pending obligation, got %s', v_obligation_count);

  RAISE NOTICE 'Test 4 PASSED: consume_trial_points decrements balance+locked and creates obligation';
END $$;


-- ===== Test 5: unlock_trial_points works =====
\echo ''
\echo '=========================================='
\echo ' Test 5: unlock_trial_points'
\echo '=========================================='

-- First, lock another point to test unlock
SELECT public.lock_trial_points(
  'aaaa0001-0000-0000-0000-000000000000',
  1,
  'matching_lock'::public.trial_point_reason,
  'Lock for unlock test'
);

DO $$
DECLARE
  v_locked_before integer;
BEGIN
  SELECT locked INTO v_locked_before
  FROM public.trial_point_wallets
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000';
  ASSERT v_locked_before = 1,
    format('Test 5 setup FAILED: expected locked=1, got %s', v_locked_before);
END $$;

SELECT public.unlock_trial_points(
  'aaaa0001-0000-0000-0000-000000000000',
  1,
  'matching_unlock'::public.trial_point_reason,
  'Unlock for test'
);

DO $$
DECLARE
  v_balance integer;
  v_locked  integer;
  v_ledger_amount integer;
BEGIN
  SELECT balance, locked INTO v_balance, v_locked
  FROM public.trial_point_wallets
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000';

  ASSERT v_locked = 0,
    format('Test 5 FAILED: locked should be 0 after unlock, got %s', v_locked);
  -- Balance should remain unchanged (unlock just moves locked -> available)
  ASSERT v_balance = 2,
    format('Test 5 FAILED: balance should still be 2, got %s', v_balance);

  SELECT amount INTO v_ledger_amount
  FROM public.trial_point_ledger
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000'
    AND reason = 'matching_unlock'
  ORDER BY created_at DESC
  LIMIT 1;

  ASSERT v_ledger_amount = 1,
    format('Test 5 FAILED: unlock ledger entry should be +1, got %s', v_ledger_amount);

  RAISE NOTICE 'Test 5 PASSED: unlock_trial_points works correctly';
END $$;


-- ===== Test 6: deactivate_trial_points sets is_active=false, preserves balance =====
\echo ''
\echo '=========================================='
\echo ' Test 6: deactivate_trial_points'
\echo '=========================================='

-- Use user 2 to avoid affecting user 1 tests
SELECT public.deactivate_trial_points('aaaa0002-0000-0000-0000-000000000000');

DO $$
DECLARE
  v_balance integer;
  v_is_active boolean;
  v_deact_count integer;
BEGIN
  SELECT balance, is_active INTO v_balance, v_is_active
  FROM public.trial_point_wallets
  WHERE user_id = 'aaaa0002-0000-0000-0000-000000000000';

  ASSERT v_is_active = false,
    'Test 6 FAILED: wallet should be deactivated';
  ASSERT v_balance = 3,
    format('Test 6 FAILED: balance should be preserved at 3, got %s', v_balance);

  SELECT COUNT(*) INTO v_deact_count
  FROM public.trial_point_ledger
  WHERE user_id = 'aaaa0002-0000-0000-0000-000000000000'
    AND reason = 'subscription_deactivation';

  ASSERT v_deact_count = 1,
    format('Test 6 FAILED: expected 1 deactivation ledger entry, got %s', v_deact_count);

  RAISE NOTICE 'Test 6 PASSED: deactivate_trial_points sets is_active=false, preserves balance';
END $$;


-- ===== Test 7: lock_trial_points fails after deactivation =====
\echo ''
\echo '=========================================='
\echo ' Test 7: lock_trial_points fails after deactivation'
\echo '=========================================='

DO $$
BEGIN
  PERFORM public.lock_trial_points(
    'aaaa0002-0000-0000-0000-000000000000',
    1
  );
  RAISE NOTICE 'Test 7 FAILED: should have raised exception for deactivated wallet';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE '%Trial point wallet is deactivated%' THEN
      RAISE NOTICE 'Test 7 PASSED: lock blocked on deactivated wallet (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 7 FAILED: unexpected error: %', SQLERRM;
      RAISE;
    END IF;
END $$;


-- ===== Test 8: deactivate_trial_points is idempotent =====
\echo ''
\echo '=========================================='
\echo ' Test 8: deactivate_trial_points is idempotent'
\echo '=========================================='

-- Call deactivate again — should not raise error, should not add another ledger entry
SELECT public.deactivate_trial_points('aaaa0002-0000-0000-0000-000000000000');

DO $$
DECLARE
  v_deact_count integer;
  v_is_active boolean;
BEGIN
  SELECT is_active INTO v_is_active
  FROM public.trial_point_wallets
  WHERE user_id = 'aaaa0002-0000-0000-0000-000000000000';

  ASSERT v_is_active = false,
    'Test 8 FAILED: wallet should still be deactivated';

  SELECT COUNT(*) INTO v_deact_count
  FROM public.trial_point_ledger
  WHERE user_id = 'aaaa0002-0000-0000-0000-000000000000'
    AND reason = 'subscription_deactivation';

  ASSERT v_deact_count = 1,
    format('Test 8 FAILED: idempotent call should not add ledger entries; got %s', v_deact_count);

  RAISE NOTICE 'Test 8 PASSED: deactivate_trial_points is idempotent';
END $$;


-- ===== Test 9: route_referee_reward fulfills obligation (FIFO) =====
\echo ''
\echo '=========================================='
\echo ' Test 9: route_referee_reward fulfills obligation (FIFO)'
\echo '=========================================='

-- Create an obligation request (is_obligation=true) for user 2 (the referee)
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source, is_obligation)
VALUES ('cccc0002-0000-0000-0000-000000000000', 'bbbb0001-0000-0000-0000-000000000000', 'standard', 'accepted', 'aaaa0002-0000-0000-0000-000000000000', now(), 'trial'::public.point_source_type, true);

-- User 1 has a pending obligation created in Test 4 (source_request_id=cccc0001)
-- Now call route_referee_reward for user 1 as referee, with is_obligation=true request
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source, is_obligation)
VALUES ('cccc0003-0000-0000-0000-000000000000', 'bbbb0001-0000-0000-0000-000000000000', 'standard', 'accepted', 'aaaa0001-0000-0000-0000-000000000000', now(), 'trial'::public.point_source_type, true);

SELECT public.route_referee_reward(
  'cccc0003-0000-0000-0000-000000000000',
  'aaaa0001-0000-0000-0000-000000000000',
  100,
  'review_completed'::public.reward_reason,
  'Obligation fulfillment test',
  'cccc0003-0000-0000-0000-000000000000'
);

DO $$
DECLARE
  v_obligation_status public.referee_obligation_status;
  v_fulfill_request_id uuid;
  v_reward_balance integer;
BEGIN
  SELECT status, fulfill_request_id INTO v_obligation_status, v_fulfill_request_id
  FROM public.referee_obligations
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000'
  ORDER BY created_at ASC
  LIMIT 1;

  ASSERT v_obligation_status = 'fulfilled',
    format('Test 9 FAILED: obligation should be fulfilled, got %s', v_obligation_status);
  ASSERT v_fulfill_request_id = 'cccc0003-0000-0000-0000-000000000000'::uuid,
    format('Test 9 FAILED: fulfill_request_id mismatch, got %s', v_fulfill_request_id);

  -- No reward should have been granted
  SELECT balance INTO v_reward_balance
  FROM public.reward_wallets
  WHERE user_id = 'aaaa0001-0000-0000-0000-000000000000';

  ASSERT (v_reward_balance IS NULL OR v_reward_balance = 0),
    format('Test 9 FAILED: no reward should be granted on obligation fulfillment, got balance=%s', v_reward_balance);

  RAISE NOTICE 'Test 9 PASSED: route_referee_reward fulfills obligation (FIFO) without granting reward';
END $$;


-- ===== Test 10: route_referee_reward grants normal reward when no obligation =====
\echo ''
\echo '=========================================='
\echo ' Test 10: route_referee_reward grants normal reward (is_obligation=false)'
\echo '=========================================='

-- cccc0002 has is_obligation=false (it was set to true above — use a new regular request)
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source, is_obligation)
VALUES ('cccc0004-0000-0000-0000-000000000000', 'bbbb0001-0000-0000-0000-000000000000', 'standard', 'accepted', 'aaaa0002-0000-0000-0000-000000000000', now(), 'regular'::public.point_source_type, false);

SELECT public.route_referee_reward(
  'cccc0004-0000-0000-0000-000000000000',
  'aaaa0002-0000-0000-0000-000000000000',
  100,
  'review_completed'::public.reward_reason,
  'Normal reward test',
  'cccc0004-0000-0000-0000-000000000000'
);

DO $$
DECLARE
  v_reward_balance integer;
  v_ledger_count integer;
BEGIN
  SELECT balance INTO v_reward_balance
  FROM public.reward_wallets
  WHERE user_id = 'aaaa0002-0000-0000-0000-000000000000';

  ASSERT v_reward_balance = 100,
    format('Test 10 FAILED: expected reward balance=100, got %s', v_reward_balance);

  SELECT COUNT(*) INTO v_ledger_count
  FROM public.reward_ledger
  WHERE user_id = 'aaaa0002-0000-0000-0000-000000000000'
    AND reason = 'review_completed';

  ASSERT v_ledger_count = 1,
    format('Test 10 FAILED: expected 1 reward ledger entry, got %s', v_ledger_count);

  RAISE NOTICE 'Test 10 PASSED: route_referee_reward grants normal reward when is_obligation=false';
END $$;


-- ===== Cleanup =====
\echo ''
\echo '=========================================='
\echo ' Cleanup'
\echo '=========================================='

ROLLBACK;

\echo 'All test data rolled back.'
\echo ''
\echo '=========================================='
\echo ' All tests complete!'
\echo '=========================================='
