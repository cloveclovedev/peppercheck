-- =============================================================================
-- Test: Evidence Timeout Settlement
--
-- Usage:
--   docker cp supabase/tests/test_evidence_timeout_settlement.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_evidence_timeout_settlement.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Evidence Timeout Settlement'
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


-- ===== Test 1: Evidence timeout detection changes status =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Evidence timeout detection'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Timeout Task', 'Desc', 'Criteria', now() - interval '1 hour', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for timeout test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'awaiting_evidence');

SELECT public.detect_and_handle_evidence_timeouts();

DO $$
BEGIN
  ASSERT (SELECT status FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'evidence_timeout',
    'Test 1 FAILED: status should be evidence_timeout';
  RAISE NOTICE 'Test 1 PASSED: detection changes status to evidence_timeout';
END $$;


-- ===== Test 2: Settlement trigger settles points and grants reward =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Settlement trigger'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 2 FAILED: tasker balance should be 9 after settlement';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 2 FAILED: tasker locked should be 0 after settlement';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 2 FAILED: referee reward should be 1';
  ASSERT (SELECT COUNT(*) FROM public.point_ledger
    WHERE user_id = '11111111-1111-1111-1111-111111111111' AND reason = 'matching_settled') >= 1,
    'Test 2 FAILED: should have matching_settled point ledger entry';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger
    WHERE user_id = '22222222-2222-2222-2222-222222222222' AND reason = 'evidence_timeout') = 1,
    'Test 2 FAILED: should have evidence_timeout reward ledger entry';
  RAISE NOTICE 'Test 2 PASSED: points consumed from tasker, reward granted to referee';
END $$;


-- ===== Test 3: Request auto-closed directly by settlement trigger =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Auto-close referee side'
\echo '=========================================='

DO $$
BEGIN
  -- is_evidence_timeout_confirmed column removed — settlement trigger now closes request directly
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 3 FAILED: request should be closed';
  RAISE NOTICE 'Test 3 PASSED: referee side auto-closed';
END $$;


-- ===== Test 4: Task stays open (is_confirmed still false) =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Task stays open for tasker'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 4 FAILED: is_confirmed should still be false';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'open',
    'Test 4 FAILED: task should still be open';
  RAISE NOTICE 'Test 4 PASSED: task stays open, tasker must confirm';
END $$;


-- ===== Test 5: Tasker confirms evidence timeout → task closes =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Tasker confirm closes task'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_evidence_timeout('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 5 FAILED: is_confirmed should be true';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 5 FAILED: task should be closed after tasker confirms';
  RAISE NOTICE 'Test 5 PASSED: tasker confirm closes task';
END $$;


-- ===== Test 6: Idempotency — second confirm does not fail =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Confirm idempotency'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_evidence_timeout('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 6 FAILED: balance should still be 9 (no double-consume)';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 6 FAILED: reward should still be 1 (no double-grant)';
  RAISE NOTICE 'Test 6 PASSED: idempotency prevents double-processing';
END $$;


-- ===== Test 7: Detection does not affect tasks with evidence =====
\echo ''
\echo '=========================================='
\echo ' Test 7: Tasks with evidence are not affected'
\echo '=========================================='

-- Create task with future due_date so evidence can be inserted
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Has Evidence Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for evidence test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'awaiting_evidence');

-- Insert evidence while due_date is still in the future
INSERT INTO public.task_evidences (id, task_id, description, status)
VALUES ('ffffffff-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'My evidence', 'ready');

-- Now move due_date to the past to simulate timeout scenario
UPDATE public.tasks SET due_date = now() - interval '1 hour' WHERE id = 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT public.detect_and_handle_evidence_timeouts();

DO $$
BEGIN
  ASSERT (SELECT status FROM public.judgements WHERE id = 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'awaiting_evidence',
    'Test 7 FAILED: status should still be awaiting_evidence (evidence exists)';
  RAISE NOTICE 'Test 7 PASSED: tasks with evidence are not affected';
END $$;


-- ===== Test 8: Normal confirm flow still works (regression) =====
\echo ''
\echo '=========================================='
\echo ' Test 8: Normal confirm flow regression'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Normal Flow Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for normal flow');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee('bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa', true, 'Good job');

DO $$
BEGIN
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 8 FAILED: request should be closed';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 8 FAILED: task should be closed';
  RAISE NOTICE 'Test 8 PASSED: normal confirm flow still works';
END $$;


-- ===== Test 9: Referee can still read task after evidence timeout (RLS) =====
\echo ''
\echo '=========================================='
\echo ' Test 9: Referee RLS access after evidence timeout'
\echo '=========================================='

-- The task from Test 1 (aaaaaaaa-...) has been through evidence timeout:
--   - task_referee_requests.status = 'closed' (verified in Test 3)
--   - task.status = 'closed' (verified in Test 5)
-- Verify that the referee can still SELECT this task via RLS.

SET LOCAL role = 'authenticated';
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}', true);

DO $$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count
    FROM public.tasks
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  ASSERT v_count = 1,
    'Test 9 FAILED: referee should be able to read the task after evidence timeout (request closed)';
  RAISE NOTICE 'Test 9 PASSED: referee can read task via RLS after request status is closed';
END $$;

-- Reset role back to postgres for cleanup
RESET role;
SELECT set_config('request.jwt.claims', NULL, true);


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
