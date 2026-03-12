-- =============================================================================
-- Test: Trial Point Settlement - End-to-End Flow
--
-- Usage:
--   docker cp supabase/tests/test_trial_point_settlement.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_trial_point_settlement.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Trial Point Settlement'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Inserting trial_point_config...'

INSERT INTO public.trial_point_config (id, initial_grant_amount)
VALUES (true, 3)
ON CONFLICT (id) DO UPDATE SET initial_grant_amount = 3;

\echo '[Setup] Creating test users (triggers handle_new_user)...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('dd110001-0000-0000-0000-000000000000', 'settle_tasker@test.com',  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('dd110002-0000-0000-0000-000000000000', 'settle_referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('dd110003-0000-0000-0000-000000000000', 'settle_regular@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Setting up point wallets (regular tasker for regular-source test)...'

UPDATE public.point_wallets
SET balance = 100, locked = 10
WHERE user_id = 'dd110003-0000-0000-0000-000000000000';

\echo '[Setup] Creating task...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dd220001-0000-0000-0000-000000000000', 'dd110001-0000-0000-0000-000000000000', 'Trial Settlement Task', 'Test description', 'Test criteria', now() + interval '7 days', 'open');

\echo '[Setup] Creating trial referee request...'

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source, is_obligation)
VALUES (
  'dd330001-0000-0000-0000-000000000000',
  'dd220001-0000-0000-0000-000000000000',
  'standard',
  'accepted',
  'dd110002-0000-0000-0000-000000000000',
  now(),
  'trial'::public.point_source_type,
  false
);

\echo '[Setup] Locking 1 trial point for the tasker...'

SELECT public.lock_trial_points(
  'dd110001-0000-0000-0000-000000000000',
  1,
  'matching_lock'::public.trial_point_reason,
  'Lock for matching',
  'dd330001-0000-0000-0000-000000000000'
);

\echo '[Setup] Creating judgement (approved)...'

INSERT INTO public.judgements (id, status)
VALUES ('dd330001-0000-0000-0000-000000000000', 'approved');


-- ===== Test 1: Trial task confirm flow - trial points consumed, obligation created, referee gets normal reward =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Trial task confirm flow'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "dd110001-0000-0000-0000-000000000000"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'dd330001-0000-0000-0000-000000000000',
  true,
  'Great job!'
);

DO $$
DECLARE
  v_balance  integer;
  v_locked   integer;
  v_is_confirmed boolean;
  v_obligation_count integer;
  v_reward_balance integer;
BEGIN
  -- 1a. judgement should be confirmed
  SELECT is_confirmed INTO v_is_confirmed
  FROM public.judgements
  WHERE id = 'dd330001-0000-0000-0000-000000000000';

  ASSERT v_is_confirmed = true,
    'Test 1 FAILED: judgement should be confirmed';

  -- 1b. trial point balance decremented (3 → 2), locked back to 0
  SELECT balance, locked INTO v_balance, v_locked
  FROM public.trial_point_wallets
  WHERE user_id = 'dd110001-0000-0000-0000-000000000000';

  ASSERT v_balance = 2,
    format('Test 1 FAILED: trial point balance should be 2 after consume, got %s', v_balance);
  ASSERT v_locked = 0,
    format('Test 1 FAILED: locked should be 0 after consume, got %s', v_locked);

  -- 1c. obligation created for tasker
  SELECT COUNT(*) INTO v_obligation_count
  FROM public.referee_obligations
  WHERE user_id = 'dd110001-0000-0000-0000-000000000000'
    AND status = 'pending'
    AND source_request_id = 'dd330001-0000-0000-0000-000000000000';

  ASSERT v_obligation_count = 1,
    format('Test 1 FAILED: expected 1 pending obligation for tasker, got %s', v_obligation_count);

  -- 1d. referee gets normal reward (is_obligation = false on the request)
  SELECT balance INTO v_reward_balance
  FROM public.reward_wallets
  WHERE user_id = 'dd110002-0000-0000-0000-000000000000';

  ASSERT v_reward_balance = 1,
    format('Test 1 FAILED: referee should have reward balance=1, got %s', v_reward_balance);

  RAISE NOTICE 'Test 1 PASSED: trial task confirm flow works (balance--, obligation created, referee rewarded)';
END $$;


-- ===== Test 2: route_consume_points routes to consume_points for regular source =====
\echo ''
\echo '=========================================='
\echo ' Test 2: route_consume_points with regular source'
\echo '=========================================='

\echo '[Setup] Creating second task and regular request...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dd220002-0000-0000-0000-000000000000', 'dd110003-0000-0000-0000-000000000000', 'Regular Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source, is_obligation)
VALUES (
  'dd330002-0000-0000-0000-000000000000',
  'dd220002-0000-0000-0000-000000000000',
  'standard',
  'accepted',
  'dd110002-0000-0000-0000-000000000000',
  now(),
  'regular'::public.point_source_type,
  false
);

-- Verify pre-conditions
DO $$
DECLARE
  v_balance integer;
  v_locked  integer;
BEGIN
  SELECT balance, locked INTO v_balance, v_locked
  FROM public.point_wallets
  WHERE user_id = 'dd110003-0000-0000-0000-000000000000';

  ASSERT v_balance = 100,
    format('Test 2 setup FAILED: expected balance=100, got %s', v_balance);
  ASSERT v_locked = 10,
    format('Test 2 setup FAILED: expected locked=10, got %s', v_locked);
END $$;

-- Call route_consume_points directly for regular source
SELECT public.route_consume_points(
  'dd330002-0000-0000-0000-000000000000',
  'dd110003-0000-0000-0000-000000000000',
  1,
  'Test regular consume',
  'dd330002-0000-0000-0000-000000000000'
);

DO $$
DECLARE
  v_balance integer;
  v_locked  integer;
  v_ledger_count integer;
BEGIN
  SELECT balance, locked INTO v_balance, v_locked
  FROM public.point_wallets
  WHERE user_id = 'dd110003-0000-0000-0000-000000000000';

  -- consume_points decrements both balance and locked
  ASSERT v_balance = 99,
    format('Test 2 FAILED: expected balance=99 after consume, got %s', v_balance);
  ASSERT v_locked = 9,
    format('Test 2 FAILED: expected locked=9 after consume, got %s', v_locked);

  -- A point_ledger entry should have been created
  SELECT COUNT(*) INTO v_ledger_count
  FROM public.point_ledger
  WHERE user_id = 'dd110003-0000-0000-0000-000000000000'
    AND reason = 'matching_settled'
    AND amount = -1;

  ASSERT v_ledger_count = 1,
    format('Test 2 FAILED: expected 1 ledger entry for matching_settled, got %s', v_ledger_count);

  -- No trial wallet change
  RAISE NOTICE 'Test 2 PASSED: route_consume_points routes to consume_points for regular source';
END $$;


-- ===== Test 3: confirm_judgement_and_rate_referee with is_obligation=true - no reward granted =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Obligation request - referee gets no reward'
\echo '=========================================='

\echo '[Setup] Creating task and obligation request for tasker user 1...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dd220003-0000-0000-0000-000000000000', 'dd110001-0000-0000-0000-000000000000', 'Obligation Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

-- is_obligation=true: referee serves obligation, no reward
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source, is_obligation)
VALUES (
  'dd330003-0000-0000-0000-000000000000',
  'dd220003-0000-0000-0000-000000000000',
  'standard',
  'accepted',
  'dd110002-0000-0000-0000-000000000000',
  now(),
  'trial'::public.point_source_type,
  true
);

-- Lock trial point for tasker (user 1 has balance=2 after Test 1)
SELECT public.lock_trial_points(
  'dd110001-0000-0000-0000-000000000000',
  1,
  'matching_lock'::public.trial_point_reason,
  'Lock for obligation task',
  'dd330003-0000-0000-0000-000000000000'
);

INSERT INTO public.judgements (id, status)
VALUES ('dd330003-0000-0000-0000-000000000000', 'approved');

-- Referee (user 2) has a pending obligation from Test 1 (source_request_id=dd330001)
-- The obligation request is_obligation=true, so route_referee_reward will fulfill it

SELECT set_config('request.jwt.claims', '{"sub": "dd110001-0000-0000-0000-000000000000"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'dd330003-0000-0000-0000-000000000000',
  true,
  'Good work'
);

DO $$
DECLARE
  v_referee_reward_balance integer;
  v_obligation_status public.referee_obligation_status;
  v_fulfill_request_id uuid;
BEGIN
  -- The referee (user 2) had reward_balance=1 from Test 1.
  -- With is_obligation=true, no additional reward should be granted.
  SELECT balance INTO v_referee_reward_balance
  FROM public.reward_wallets
  WHERE user_id = 'dd110002-0000-0000-0000-000000000000';

  -- reward_balance should still be 1 (no new reward)
  ASSERT v_referee_reward_balance = 1,
    format('Test 3 FAILED: reward balance should still be 1 (no new grant), got %s', v_referee_reward_balance);

  -- The pending obligation created for user 1 in Test 1 should be fulfilled by this obligation request
  -- (user 1 is tasker here and referee for the obligation fulfillment request)
  -- Actually: is_obligation=true on the REQUEST means the referee (user 2) is fulfilling their obligation
  -- So user 2's oldest pending obligation (if any) would be fulfilled.
  -- User 2 has no obligations (they received points in Test 1), so no obligation fulfillment here.
  -- Check user 1's obligation (from Test 1) - still pending since user 2 has is_obligation=true
  -- but user 1 is the tasker not the referee in this scenario.
  -- The obligation for user 1 (from Test 1) is unrelated to this flow.

  RAISE NOTICE 'Test 3 PASSED: obligation request - referee gets no reward (balance unchanged at 1)';
END $$;


-- ===== Test 4: Full obligation fulfillment cycle =====
-- User 1 consumed trial points (Test 1), creating an obligation.
-- Now user 1 serves as referee with is_obligation=true, fulfilling their own obligation.
\echo ''
\echo '=========================================='
\echo ' Test 4: Full obligation fulfillment cycle (user fulfills own obligation)'
\echo '=========================================='

\echo '[Setup] Creating task for user 3 (regular) with obligation request for user 1 (referee)...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dd220004-0000-0000-0000-000000000000', 'dd110003-0000-0000-0000-000000000000', 'Obligation Fulfillment Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

-- User 1 is the referee here, with is_obligation=true
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at, point_source, is_obligation)
VALUES (
  'dd330004-0000-0000-0000-000000000000',
  'dd220004-0000-0000-0000-000000000000',
  'standard',
  'accepted',
  'dd110001-0000-0000-0000-000000000000',
  now(),
  'regular'::public.point_source_type,
  true
);

-- Regular source, so lock regular points for tasker (user 3, balance=99, locked=9 after Test 2)
SELECT public.lock_points(
  'dd110003-0000-0000-0000-000000000000',
  1,
  'matching_lock'::public.point_reason,
  'Lock for obligation fulfillment task',
  'dd330004-0000-0000-0000-000000000000'
);

INSERT INTO public.judgements (id, status)
VALUES ('dd330004-0000-0000-0000-000000000000', 'approved');

SELECT set_config('request.jwt.claims', '{"sub": "dd110003-0000-0000-0000-000000000000"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'dd330004-0000-0000-0000-000000000000',
  true,
  'Obligation fulfilled'
);

DO $$
DECLARE
  v_obligation_status public.referee_obligation_status;
  v_fulfill_request_id uuid;
  v_user1_reward_balance integer;
BEGIN
  -- User 1's pending obligation (from Test 1, source_request_id=dd330001) should be fulfilled
  SELECT status, fulfill_request_id INTO v_obligation_status, v_fulfill_request_id
  FROM public.referee_obligations
  WHERE user_id = 'dd110001-0000-0000-0000-000000000000'
    AND source_request_id = 'dd330001-0000-0000-0000-000000000000';

  ASSERT v_obligation_status = 'fulfilled',
    format('Test 4 FAILED: obligation should be fulfilled, got %s', v_obligation_status);
  ASSERT v_fulfill_request_id = 'dd330004-0000-0000-0000-000000000000'::uuid,
    format('Test 4 FAILED: fulfill_request_id should be dd330004, got %s', v_fulfill_request_id);

  -- User 1 (referee here) should NOT have received a reward (is_obligation=true)
  SELECT balance INTO v_user1_reward_balance
  FROM public.reward_wallets
  WHERE user_id = 'dd110001-0000-0000-0000-000000000000';

  ASSERT (v_user1_reward_balance IS NULL OR v_user1_reward_balance = 0),
    format('Test 4 FAILED: user 1 should not receive reward on obligation request, got balance=%s', v_user1_reward_balance);

  RAISE NOTICE 'Test 4 PASSED: obligation fulfilled (FIFO), no reward granted to referee';
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
