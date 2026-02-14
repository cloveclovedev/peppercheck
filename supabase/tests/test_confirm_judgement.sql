-- =============================================================================
-- Test: confirm_judgement_and_rate_referee RPC
--
-- Usage:
--   docker cp supabase/tests/test_confirm_judgement.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_confirm_judgement.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: confirm_judgement_and_rate_referee'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Creating test users...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Setting up point wallets...'

UPDATE public.point_wallets
SET balance = 100, locked = 10
WHERE user_id = '11111111-1111-1111-1111-111111111111';

\echo '[Setup] Creating task...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Task', 'Test description', 'Test criteria', now() + interval '7 days', 'open');

\echo '[Setup] Creating referee request...'

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

\echo '[Setup] Creating judgement (approved)...'

INSERT INTO public.judgements (id, status)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'approved');


-- ===== Test 1: Confirm approved judgement with positive rating =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Confirm approved (positive rating)'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  true,
  'Great referee!'
);

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = true,
    'Test 1 FAILED: judgement should be confirmed';
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = true,
    'Test 1 FAILED: rating should be positive';
  ASSERT (SELECT rater_id FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = '11111111-1111-1111-1111-111111111111'::uuid,
    'Test 1 FAILED: rater_id should be tasker';
  ASSERT (SELECT ratee_id FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = '22222222-2222-2222-2222-222222222222'::uuid,
    'Test 1 FAILED: ratee_id should be referee';
  ASSERT (SELECT comment FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = 'Great referee!',
    'Test 1 FAILED: comment mismatch';
  RAISE NOTICE 'Test 1 PASSED: confirm approved with positive rating';
END $$;


-- ===== Test 2: Idempotency - confirming again does nothing =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Idempotency'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  false,
  'Changed my mind'
);

DO $$
BEGIN
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = true,
    'Test 2 FAILED: rating should still be positive (idempotency)';
  ASSERT (SELECT COUNT(*) FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 1,
    'Test 2 FAILED: should still have exactly 1 rating';
  RAISE NOTICE 'Test 2 PASSED: idempotency works';
END $$;


-- ===== Test 3: Confirm rejected judgement with negative rating =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Confirm rejected (negative rating)'
\echo '=========================================='

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'rejected');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  false,
  'Review was unfair'
);

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') = true,
    'Test 3 FAILED: judgement should be confirmed';
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND rating_type = 'referee') = false,
    'Test 3 FAILED: rating should be negative';
  RAISE NOTICE 'Test 3 PASSED: confirm rejected with negative rating';
END $$;


-- ===== Test 4: Non-tasker cannot confirm =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Non-tasker cannot confirm'
\echo '=========================================='

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'approved');

SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

DO $$
BEGIN
  PERFORM public.confirm_judgement_and_rate_referee(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    true,
    'Trying as referee'
  );
  RAISE NOTICE 'Test 4 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Only the tasker can confirm a judgement' THEN
      RAISE NOTICE 'Test 4 PASSED: non-tasker blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 4 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 5: Cannot confirm in_review status =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Cannot confirm in_review'
\echo '=========================================='

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'in_review');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

DO $$
BEGIN
  PERFORM public.confirm_judgement_and_rate_referee(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    true,
    'Trying to confirm in_review'
  );
  RAISE NOTICE 'Test 5 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Judgement must be in approved or rejected status to confirm' THEN
      RAISE NOTICE 'Test 5 PASSED: in_review blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 5 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 6: Close flow - confirm triggers request close =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Confirm triggers request close'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 'closed',
    'Test 6 FAILED: referee request should be closed after confirm';
  RAISE NOTICE 'Test 6 PASSED: request closed on confirm';
END $$;


-- ===== Test 7: Close flow - all confirmed closes task =====
\echo ''
\echo '=========================================='
\echo ' Test 7: All confirmed closes task'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  true,
  'Good job'
);

SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
SELECT public.judge_evidence('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'approved', 'Approving');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
SELECT public.confirm_judgement_and_rate_referee(
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  true,
  'Also good'
);

DO $$
BEGIN
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 7 FAILED: task should be closed when all requests are closed';
  RAISE NOTICE 'Test 7 PASSED: task closed when all requests closed';
END $$;


-- ===== Test 8: Confirm without comment =====
\echo ''
\echo '=========================================='
\echo ' Test 8: Confirm without comment'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('ffffffff-ffff-ffff-ffff-ffffffffffff', '11111111-1111-1111-1111-111111111111', 'Task 2', 'Desc', 'Criteria', now() + interval '7 days', 'open');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('99999999-9999-9999-9999-999999999999', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('99999999-9999-9999-9999-999999999999', 'approved');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  '99999999-9999-9999-9999-999999999999',
  true
);

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = '99999999-9999-9999-9999-999999999999') = true,
    'Test 8 FAILED: should confirm without comment';
  ASSERT (SELECT comment FROM public.rating_histories WHERE judgement_id = '99999999-9999-9999-9999-999999999999') IS NULL,
    'Test 8 FAILED: comment should be NULL';
  RAISE NOTICE 'Test 8 PASSED: confirm without comment works';
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
