-- =============================================================================
-- Test: Auto Confirm
--
-- Usage:
--   docker cp supabase/tests/test_auto_confirm.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_auto_confirm.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Auto Confirm'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Cleaning up existing test data...'

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

\echo '[Setup] Setting point wallet...'

UPDATE public.point_wallets
SET balance = 10, locked = 0
WHERE user_id = '11111111-1111-1111-1111-111111111111';


-- ===== Test 1: Auto-confirm approved judgement =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Auto-confirm approved judgement (settlement + rating)'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Approved Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for approved test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

SELECT public.detect_auto_confirms();

DO $$
BEGIN
  -- Verify is_confirmed and is_auto_confirmed flags
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 1 FAILED: is_confirmed should be true';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 1 FAILED: is_auto_confirmed should be true';

  -- Verify settlement
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 1 FAILED: tasker balance should be 9 after settlement';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 1 FAILED: tasker locked should be 0 after settlement';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 1 FAILED: referee reward should be 1';

  -- Verify auto-positive rating
  ASSERT (SELECT is_positive FROM public.rating_histories
    WHERE judgement_id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND rating_type = 'referee') = true,
    'Test 1 FAILED: should have auto-positive rating';
  ASSERT (SELECT rater_id FROM public.rating_histories
    WHERE judgement_id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND rating_type = 'referee') = '11111111-1111-1111-1111-111111111111',
    'Test 1 FAILED: rater should be the tasker';

  -- Verify request and task closed
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 1 FAILED: request should be closed';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 1 FAILED: task should be closed';

  RAISE NOTICE 'Test 1 PASSED: approved judgement auto-confirmed with settlement + rating';
END $$;


-- ===== Test 2: Auto-confirm rejected judgement =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Auto-confirm rejected judgement'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Rejected Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for rejected test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'rejected');

SELECT public.detect_auto_confirms();

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 2 FAILED: is_confirmed should be true';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 2 FAILED: is_auto_confirmed should be true';
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 8,
    'Test 2 FAILED: tasker balance should be 8 after second settlement';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 2,
    'Test 2 FAILED: referee reward should be 2';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 2 FAILED: task should be closed';

  RAISE NOTICE 'Test 2 PASSED: rejected judgement auto-confirmed with settlement';
END $$;


-- ===== Test 3: Auto-confirm review_timeout judgement (no settlement) =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Auto-confirm review_timeout (no settlement)'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Review Timeout Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for review timeout test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa', 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'closed', '22222222-2222-2222-2222-222222222222', now());

-- review_timeout: settlement already done (points unlocked, request closed, negative rating)
-- Simulate post-settlement state
INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa', 'review_timeout');

-- Unlock points to simulate settle_review_timeout already ran
SELECT public.unlock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_unlock'::public.point_reason, 'Simulated review timeout unlock');

-- Record current balances before auto-confirm
DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 3 FAILED: is_confirmed should be true';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 3 FAILED: is_auto_confirmed should be true';

  -- No additional settlement should occur
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 3 FAILED: tasker balance should not change (already settled)';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 3 FAILED: referee reward should not change (already settled)';

  ASSERT (SELECT status FROM public.tasks WHERE id = 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 3 FAILED: task should be closed';

  RAISE NOTICE 'Test 3 PASSED: review_timeout auto-confirmed without additional settlement';
END $$;


-- ===== Test 4: Auto-confirm evidence_timeout judgement (no settlement) =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Auto-confirm evidence_timeout (no settlement)'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Evidence Timeout Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for evidence timeout test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-eeee-aaaa-aaaa-aaaaaaaaaaaa', 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'closed', '22222222-2222-2222-2222-222222222222', now());

-- evidence_timeout: settlement already done (points consumed, reward granted, request closed)
-- Simulate post-settlement state
INSERT INTO public.judgements (id, status, is_evidence_timeout_confirmed)
VALUES ('cccccccc-eeee-aaaa-aaaa-aaaaaaaaaaaa', 'evidence_timeout', true);

-- Consume points to simulate settle_evidence_timeout already ran
SELECT public.consume_points('11111111-1111-1111-1111-111111111111', 1, 'matching_settled'::public.point_reason, 'Simulated evidence timeout consume');

-- Grant reward to simulate settle_evidence_timeout already ran
SELECT public.grant_reward('22222222-2222-2222-2222-222222222222', 1, 'evidence_timeout'::public.reward_reason, 'Simulated evidence timeout reward');

DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-eeee-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 4 FAILED: is_confirmed should be true';

  -- No additional settlement
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 4 FAILED: tasker balance should not change';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 4 FAILED: referee reward should not change';

  ASSERT (SELECT status FROM public.tasks WHERE id = 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 4 FAILED: task should be closed';

  RAISE NOTICE 'Test 4 PASSED: evidence_timeout auto-confirmed without additional settlement';
END $$;


-- ===== Test 5: Does NOT auto-confirm within grace period =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Does NOT auto-confirm within grace period'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('ffffffff-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Within Grace Task', 'Desc', 'Criteria', now() - interval '2 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for grace period test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa', 'ffffffff-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

SELECT public.detect_auto_confirms();

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 5 FAILED: is_confirmed should be false (within grace period)';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 5 FAILED: is_auto_confirmed should be false (within grace period)';

  RAISE NOTICE 'Test 5 PASSED: judgement within grace period not auto-confirmed';
END $$;


-- ===== Test 6: Idempotency — running again does not double-process =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Idempotency'
\echo '=========================================='

DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 6 FAILED: balance should not change on re-run';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 6 FAILED: reward should not change on re-run';

  RAISE NOTICE 'Test 6 PASSED: idempotency prevents double-processing';
END $$;


-- ===== Test 7: Already manually confirmed judgements are skipped =====
\echo ''
\echo '=========================================='
\echo ' Test 7: Already confirmed judgements are skipped'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Already Confirmed', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for already confirmed test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-1111-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status, is_confirmed)
VALUES ('cccccccc-1111-aaaa-aaaa-aaaaaaaaaaaa', 'approved', true);

-- Manually settle (simulating manual confirm was done)
SELECT public.consume_points('11111111-1111-1111-1111-111111111111', 1, 'matching_settled'::public.point_reason, 'Manual confirm');
SELECT public.grant_reward('22222222-2222-2222-2222-222222222222', 1, 'review_completed'::public.reward_reason, 'Manual confirm');

DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-1111-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 7 FAILED: is_auto_confirmed should remain false';
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 7 FAILED: balance should not change for already confirmed';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 7 FAILED: reward should not change for already confirmed';

  RAISE NOTICE 'Test 7 PASSED: already confirmed judgements are skipped';
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
