-- =============================================================================
-- Test: Reward System & Point Lock/Settle
--
-- Usage:
--   docker cp supabase/tests/test_reward_system.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_reward_system.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Reward System & Point Lock/Settle'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Cleaning up existing test data...'

-- Delete existing test data (in reverse dependency order)
DELETE FROM public.rating_histories WHERE judgement_id IN (
  SELECT id FROM public.judgements WHERE id IN (
    SELECT id FROM public.task_referee_requests WHERE task_id IN (
      SELECT id FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
    )
  )
);
DELETE FROM public.judgements WHERE id IN (
  SELECT id FROM public.task_referee_requests WHERE task_id IN (
    SELECT id FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
  )
);
DELETE FROM public.task_referee_requests WHERE task_id IN (
  SELECT id FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
);
DELETE FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.reward_ledger WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.point_ledger WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.reward_wallets WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.point_wallets WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM auth.users WHERE id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

\echo '[Setup] Creating test users...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Setting point wallet to 10 points...'

-- Update the wallet created by the trigger
UPDATE public.point_wallets
SET balance = 10, locked = 0
WHERE user_id = '11111111-1111-1111-1111-111111111111';

\echo '[Setup] Creating task...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Task', 'Test description', 'Test criteria', now() + interval '7 days', 'open');


-- ===== Test 1: lock_points locks but does not reduce balance =====
\echo ''
\echo '=========================================='
\echo ' Test 1: lock_points'
\echo '=========================================='

SELECT public.lock_points(
  '11111111-1111-1111-1111-111111111111',
  1,
  'matching_lock'::public.point_reason,
  'Test lock',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 10,
    'Test 1 FAILED: balance should remain 10';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 1 FAILED: locked should be 1';
  ASSERT (SELECT COUNT(*) FROM public.point_ledger WHERE user_id = '11111111-1111-1111-1111-111111111111' AND reason = 'matching_lock') = 1,
    'Test 1 FAILED: should have ledger entry';
  RAISE NOTICE 'Test 1 PASSED: lock_points locks without reducing balance';
END $$;


-- ===== Test 2: lock_points fails when insufficient available points =====
\echo ''
\echo '=========================================='
\echo ' Test 2: lock_points insufficient available'
\echo '=========================================='

-- Lock 8 more (total locked: 9, available: 1)
SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 8, 'matching_lock'::public.point_reason);

DO $$
BEGIN
  -- Try to lock 2 more (only 1 available)
  PERFORM public.lock_points('11111111-1111-1111-1111-111111111111', 2, 'matching_lock'::public.point_reason);
  RAISE NOTICE 'Test 2 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Insufficient available points%' THEN
      RAISE NOTICE 'Test 2 PASSED: insufficient available blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 2 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 3: unlock_points returns locked points to available =====
\echo ''
\echo '=========================================='
\echo ' Test 3: unlock_points'
\echo '=========================================='

SELECT public.unlock_points(
  '11111111-1111-1111-1111-111111111111',
  8,
  'matching_unlock'::public.point_reason,
  'Test unlock'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 10,
    'Test 3 FAILED: balance should remain 10';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 3 FAILED: locked should be 1';
  RAISE NOTICE 'Test 3 PASSED: unlock_points returns locked to available';
END $$;


-- ===== Test 4: consume_points settles (deducts from balance and locked) =====
\echo ''
\echo '=========================================='
\echo ' Test 4: consume_points settles'
\echo '=========================================='

SELECT public.consume_points(
  '11111111-1111-1111-1111-111111111111',
  1,
  'matching_settled'::public.point_reason,
  'Test settle'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 4 FAILED: balance should be 9';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 4 FAILED: locked should be 0';
  RAISE NOTICE 'Test 4 PASSED: consume_points settles locked points';
END $$;


-- ===== Test 5: consume_points fails when insufficient locked =====
\echo ''
\echo '=========================================='
\echo ' Test 5: consume_points insufficient locked'
\echo '=========================================='

DO $$
BEGIN
  -- No locked points, so consume should fail
  PERFORM public.consume_points('11111111-1111-1111-1111-111111111111', 1, 'matching_settled'::public.point_reason);
  RAISE NOTICE 'Test 5 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Insufficient locked points%' THEN
      RAISE NOTICE 'Test 5 PASSED: insufficient locked blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 5 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 6: grant_reward creates wallet and adds reward =====
\echo ''
\echo '=========================================='
\echo ' Test 6: grant_reward'
\echo '=========================================='

SELECT public.grant_reward(
  '22222222-2222-2222-2222-222222222222',
  1,
  'review_completed'::public.reward_reason,
  'Test reward',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 6 FAILED: reward balance should be 1';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 6 FAILED: should have 1 ledger entry';
  RAISE NOTICE 'Test 6 PASSED: grant_reward creates wallet and records ledger';
END $$;


-- ===== Test 7: grant_reward accumulates on existing wallet =====
\echo ''
\echo '=========================================='
\echo ' Test 7: grant_reward accumulates'
\echo '=========================================='

SELECT public.grant_reward(
  '22222222-2222-2222-2222-222222222222',
  2,
  'review_completed'::public.reward_reason,
  'Second reward'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 3,
    'Test 7 FAILED: reward balance should be 3';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222') = 2,
    'Test 7 FAILED: should have 2 ledger entries';
  RAISE NOTICE 'Test 7 PASSED: grant_reward accumulates rewards';
END $$;


-- ===== Test 8: Full confirm flow — lock, confirm, settle, reward =====
\echo ''
\echo '=========================================='
\echo ' Test 8: Full confirm flow'
\echo '=========================================='

-- Reset: set wallet to clean state
UPDATE public.point_wallets SET balance = 5, locked = 0 WHERE user_id = '11111111-1111-1111-1111-111111111111';
DELETE FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';
DELETE FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222';

-- Create a fresh task for this test
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Confirm Flow Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

-- Simulate create_matching_request: lock 1 point
SELECT public.lock_points(
  '11111111-1111-1111-1111-111111111111',
  1,
  'matching_lock'::public.point_reason,
  'Matching Request (standard)',
  'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

-- Create request and judgement
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

-- Verify state before confirm
DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 5,
    'Test 8 pre-check FAILED: balance should be 5 (locked, not consumed)';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 8 pre-check FAILED: locked should be 1';
  RAISE NOTICE 'Test 8 pre-check: balance=5, locked=1 (correct)';
END $$;

-- Confirm judgement (as tasker)
SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  true,
  'Great review!'
);

-- Verify state after confirm
DO $$
BEGIN
  -- Tasker: balance reduced by 1, locked reduced by 1
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 4,
    'Test 8 FAILED: tasker balance should be 4 after settle';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 8 FAILED: tasker locked should be 0 after settle';

  -- Referee: reward wallet created with 1 point
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 8 FAILED: referee reward should be 1';

  -- Ledger entries
  ASSERT (SELECT COUNT(*) FROM public.point_ledger WHERE user_id = '11111111-1111-1111-1111-111111111111' AND reason = 'matching_settled') >= 1,
    'Test 8 FAILED: should have matching_settled ledger entry';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222' AND reason = 'review_completed') = 1,
    'Test 8 FAILED: should have review_completed reward ledger entry';

  -- Judgement confirmed
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 8 FAILED: judgement should be confirmed';

  -- Rating recorded
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 8 FAILED: rating should be positive';

  RAISE NOTICE 'Test 8 PASSED: full confirm flow — lock, confirm, settle, reward all correct';
END $$;


-- ===== Test 9: Idempotency — second confirm does not double-spend =====
\echo ''
\echo '=========================================='
\echo ' Test 9: Confirm idempotency (no double-spend)'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  false,
  'Changed mind'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 4,
    'Test 9 FAILED: balance should still be 4 (no double-spend)';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 9 FAILED: reward should still be 1 (no double-grant)';
  RAISE NOTICE 'Test 9 PASSED: idempotency prevents double-spend';
END $$;


-- ===== Test 10: create_task_referee_requests_from_json locks points =====
\echo ''
\echo '=========================================='
\echo ' Test 10: create_task_referee_requests_from_json locks points'
\echo '=========================================='

-- Reset state
UPDATE public.point_wallets SET balance = 5, locked = 0 WHERE user_id = '11111111-1111-1111-1111-111111111111';

-- Create a fresh task (inserted directly, not via RPC, to isolate the helper)
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Lock Test Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

-- Call the helper that should now lock points
SELECT public.create_task_referee_requests_from_json(
  'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  ARRAY['{"matching_strategy": "standard"}'::jsonb]
);

DO $$
BEGIN
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 10 FAILED: locked should be 1 after create_task_referee_requests_from_json';
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 5,
    'Test 10 FAILED: balance should remain 5 (lock does not deduct balance)';
  ASSERT (SELECT COUNT(*) FROM public.point_ledger
    WHERE user_id = '11111111-1111-1111-1111-111111111111'
    AND reason = 'matching_lock'
    AND related_id = 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa') >= 1,
    'Test 10 FAILED: should have matching_lock ledger entry for this task';
  RAISE NOTICE 'Test 10 PASSED: create_task_referee_requests_from_json locks points correctly';
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
