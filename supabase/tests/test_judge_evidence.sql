-- =============================================================================
-- Test: judge_evidence RPC & on_judgements_status_changed trigger
--
-- Usage:
--   docker cp supabase/tests/test_judge_evidence.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_judge_evidence.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: judge_evidence RPC'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Creating test users...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Creating task...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Task', 'Test description', 'Test criteria', now() + interval '7 days', 'open');

\echo '[Setup] Creating referee request (direct insert, skip matching trigger)...'

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

\echo '[Setup] Creating judgement (in_review)...'

INSERT INTO public.judgements (id, status)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'in_review');

\echo '[Setup] Verifying initial state...'

SELECT j.id, j.status, j.comment, trr.matched_referee_id AS referee_id, t.tasker_id
FROM public.judgements j
JOIN public.task_referee_requests trr ON trr.id = j.id
JOIN public.tasks t ON t.id = trr.task_id;


-- ===== Test 1: Approve (happy path) =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Approve (happy path)'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

SELECT public.judge_evidence(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'approved',
  'Great work! Evidence is clear and meets all criteria.'
);

SELECT id, status, comment FROM public.judgements WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

DO $$
BEGIN
  ASSERT (SELECT status FROM public.judgements WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 'approved',
    'Test 1 FAILED: status should be approved';
  ASSERT (SELECT comment FROM public.judgements WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 'Great work! Evidence is clear and meets all criteria.',
    'Test 1 FAILED: comment mismatch';
  RAISE NOTICE 'Test 1 PASSED: approve works correctly';
END $$;


-- ===== Test 2: Reject (happy path) =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Reject (happy path)'
\echo '=========================================='

UPDATE public.judgements SET status = 'in_review', comment = NULL WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

SELECT public.judge_evidence(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'rejected',
  'Evidence does not match the criteria. Please provide clearer photos.'
);

DO $$
BEGIN
  ASSERT (SELECT status FROM public.judgements WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 'rejected',
    'Test 2 FAILED: status should be rejected';
  RAISE NOTICE 'Test 2 PASSED: reject works correctly';
END $$;


-- ===== Test 3: Comment is trimmed =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Comment is trimmed'
\echo '=========================================='

UPDATE public.judgements SET status = 'in_review', comment = NULL WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

SELECT public.judge_evidence(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'approved',
  '  Trimmed comment  '
);

DO $$
BEGIN
  ASSERT (SELECT comment FROM public.judgements WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 'Trimmed comment',
    'Test 3 FAILED: comment should be trimmed';
  RAISE NOTICE 'Test 3 PASSED: comment is trimmed';
END $$;


-- ===== Test 4: Non-referee cannot judge =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Non-referee cannot judge'
\echo '=========================================='

UPDATE public.judgements SET status = 'in_review', comment = NULL WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

DO $$
BEGIN
  PERFORM public.judge_evidence(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'approved',
    'Trying to approve my own task'
  );
  RAISE NOTICE 'Test 4 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Only the assigned referee can judge evidence' THEN
      RAISE NOTICE 'Test 4 PASSED: non-referee blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 4 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 5: Empty comment rejected =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Empty comment rejected'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

DO $$
BEGIN
  PERFORM public.judge_evidence(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'approved',
    ''
  );
  RAISE NOTICE 'Test 5 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Comment is required' THEN
      RAISE NOTICE 'Test 5 PASSED: empty comment blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 5 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 6: Invalid status rejected =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Invalid status rejected'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

DO $$
BEGIN
  PERFORM public.judge_evidence(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'awaiting_evidence',
    'Trying invalid status'
  );
  RAISE NOTICE 'Test 6 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Status must be approved or rejected' THEN
      RAISE NOTICE 'Test 6 PASSED: invalid status blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 6 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 7: Cannot judge when not in_review =====
\echo ''
\echo '=========================================='
\echo ' Test 7: Cannot judge when not in_review'
\echo '=========================================='

-- Status is still in_review from test 5/6 (they failed before updating)
-- Approve it first, then try again
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

SELECT public.judge_evidence(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'approved',
  'Approving first'
);

DO $$
BEGIN
  PERFORM public.judge_evidence(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'rejected',
    'Double judge attempt'
  );
  RAISE NOTICE 'Test 7 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Judgement must be in_review status to approve or reject' THEN
      RAISE NOTICE 'Test 7 PASSED: non-in_review blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 7 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Cleanup =====
\echo ''
\echo '=========================================='
\echo ' Cleanup'
\echo '=========================================='

-- ROLLBACK undoes everything including test data
ROLLBACK;

\echo 'All test data rolled back.'
\echo ''
\echo '=========================================='
\echo ' All tests complete!'
\echo '=========================================='
