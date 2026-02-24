-- =============================================================================
-- Test: Referee Availability Enhancements
--
-- Covers:
--   1. matching_time_config singleton constraint
--   2. matching_time_config ordering_invariant CHECK
--   3. Blocked dates CRUD via RPCs
--   4. Blocked dates exclude referee from matching
--   5. cancel_referee_assignment — happy path with re-match
--   6. cancel_referee_assignment — rejected past cancel deadline
--   7. Cancelled referee excluded from re-matching (double-cancel → pending)
--   8. process_pending_requests — expire + refund
--
-- Usage:
--   docker cp supabase/tests/test_referee_availability.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_referee_availability.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Referee Availability Enhancements'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Creating test users...'

-- Tasker: user A (11111111-...)
-- Referee B: user B (22222222-...)
-- Referee C: user C (33333333-...)

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'tasker_avail@test.com',   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee_b_avail@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('33333333-3333-3333-3333-333333333333', 'referee_c_avail@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Setting point wallets...'

-- Tasker needs enough points for matching (standard = 1 pt)
UPDATE public.point_wallets
SET balance = 100, locked = 0
WHERE user_id = '11111111-1111-1111-1111-111111111111';

-- Referees don't need points
UPDATE public.point_wallets
SET balance = 0, locked = 0
WHERE user_id IN ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');


-- =============================================================================
-- Test 1: matching_time_config — seed data exists
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 1: matching_time_config seed data'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT open_deadline_hours FROM public.matching_time_config WHERE id = true) = 24,
    'Test 1 FAILED: open_deadline_hours should be 24';
  ASSERT (SELECT cancel_deadline_hours FROM public.matching_time_config WHERE id = true) = 12,
    'Test 1 FAILED: cancel_deadline_hours should be 12';
  ASSERT (SELECT rematch_cutoff_hours FROM public.matching_time_config WHERE id = true) = 14,
    'Test 1 FAILED: rematch_cutoff_hours should be 14';
  RAISE NOTICE 'Test 1 PASSED: matching_time_config seed data correct (24, 12, 14)';
END $$;


-- =============================================================================
-- Test 2: matching_time_config — singleton constraint prevents second row
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 2: matching_time_config singleton'
\echo '=========================================='

DO $$
BEGIN
  -- Attempt to insert a second row (id = true is the only valid value due to singleton CHECK)
  INSERT INTO public.matching_time_config (open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours)
  VALUES (48, 6, 12);
  RAISE NOTICE 'Test 2 FAILED: second INSERT should have been rejected by unique constraint';
EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE 'Test 2 PASSED: singleton constraint blocks second row (unique_violation)';
  WHEN OTHERS THEN
    RAISE NOTICE 'Test 2 PASSED: singleton constraint blocks second row (error: %)', SQLERRM;
END $$;


-- =============================================================================
-- Test 3: matching_time_config — ordering_invariant rejects cancel > rematch
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 3: matching_time_config ordering_invariant'
\echo '=========================================='

DO $$
BEGIN
  -- Try to set cancel_deadline_hours > rematch_cutoff_hours (violates ordering_invariant)
  UPDATE public.matching_time_config
  SET cancel_deadline_hours = 20, rematch_cutoff_hours = 15
  WHERE id = true;
  RAISE NOTICE 'Test 3 FAILED: UPDATE should have been rejected by ordering_invariant CHECK';
EXCEPTION
  WHEN check_violation THEN
    RAISE NOTICE 'Test 3 PASSED: ordering_invariant CHECK rejected cancel > rematch (check_violation)';
  WHEN OTHERS THEN
    RAISE NOTICE 'Test 3 FAILED: unexpected error: %', SQLERRM;
END $$;

-- Confirm config was not changed
DO $$
BEGIN
  ASSERT (SELECT cancel_deadline_hours FROM public.matching_time_config WHERE id = true) = 12,
    'Test 3 post-check FAILED: config should be unchanged after failed UPDATE';
  RAISE NOTICE 'Test 3 post-check PASSED: config unchanged';
END $$;


-- =============================================================================
-- Test 4: Blocked dates CRUD via RPCs (create / update / delete / validation)
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 4: Blocked dates CRUD RPCs'
\echo '=========================================='

-- Set auth context to referee B
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
SET LOCAL role = 'authenticated';

-- 4a: create
DO $$
DECLARE
  v_id uuid;
BEGIN
  v_id := public.create_referee_blocked_date('2026-03-01'::date, '2026-03-05'::date, 'Holiday');
  ASSERT v_id IS NOT NULL, 'Test 4a FAILED: create should return a UUID';
  ASSERT (SELECT start_date FROM public.referee_blocked_dates WHERE id = v_id) = '2026-03-01'::date,
    'Test 4a FAILED: start_date mismatch';
  ASSERT (SELECT end_date FROM public.referee_blocked_dates WHERE id = v_id) = '2026-03-05'::date,
    'Test 4a FAILED: end_date mismatch';
  ASSERT (SELECT reason FROM public.referee_blocked_dates WHERE id = v_id) = 'Holiday',
    'Test 4a FAILED: reason mismatch';
  ASSERT (SELECT user_id FROM public.referee_blocked_dates WHERE id = v_id) = '22222222-2222-2222-2222-222222222222'::uuid,
    'Test 4a FAILED: user_id mismatch';

  -- Store id for subsequent sub-tests
  PERFORM set_config('app.test_blocked_date_id', v_id::text, true);

  RAISE NOTICE 'Test 4a PASSED: create_referee_blocked_date creates row correctly';
END $$;

-- 4b: update
DO $$
DECLARE
  v_id uuid;
BEGIN
  v_id := current_setting('app.test_blocked_date_id')::uuid;
  PERFORM public.update_referee_blocked_date(v_id, '2026-03-02'::date, '2026-03-07'::date, 'Extended Holiday');
  ASSERT (SELECT start_date FROM public.referee_blocked_dates WHERE id = v_id) = '2026-03-02'::date,
    'Test 4b FAILED: start_date should be updated';
  ASSERT (SELECT end_date FROM public.referee_blocked_dates WHERE id = v_id) = '2026-03-07'::date,
    'Test 4b FAILED: end_date should be updated';
  ASSERT (SELECT reason FROM public.referee_blocked_dates WHERE id = v_id) = 'Extended Holiday',
    'Test 4b FAILED: reason should be updated';
  RAISE NOTICE 'Test 4b PASSED: update_referee_blocked_date updates correctly';
END $$;

-- 4c: delete
DO $$
DECLARE
  v_id uuid;
  v_count int;
BEGIN
  v_id := current_setting('app.test_blocked_date_id')::uuid;
  PERFORM public.delete_referee_blocked_date(v_id);
  SELECT COUNT(*) INTO v_count FROM public.referee_blocked_dates WHERE id = v_id;
  ASSERT v_count = 0, 'Test 4c FAILED: row should be deleted';
  RAISE NOTICE 'Test 4c PASSED: delete_referee_blocked_date removes row';
END $$;

-- 4d: date range validation (end_date < start_date must fail)
DO $$
BEGIN
  PERFORM public.create_referee_blocked_date('2026-03-10'::date, '2026-03-01'::date, 'Invalid');
  RAISE NOTICE 'Test 4d FAILED: end_date < start_date should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE '%end_date must be >= start_date%' THEN
      RAISE NOTICE 'Test 4d PASSED: date range validation rejects end_date < start_date (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 4d FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;

-- Reset role for remaining setup
SET LOCAL role = 'postgres';


-- =============================================================================
-- Test 5: Blocked dates exclude referee from matching
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 5: Blocked dates exclude referee from matching'
\echo '=========================================='

-- We need a task whose due_date lands on a specific DOW at a specific time.
-- Use NOW() + interval '48 hours' to be well past the 24h open deadline.
-- We'll set availability slots for that exact DOW + time range for both B and C.
-- Then block referee B for that date — only C should be matched.

DO $$
DECLARE
  v_task_id uuid := 'aaaaaaaa-0005-0000-0000-000000000000';
  v_request_id uuid;
  v_due_date timestamptz;
  v_due_dow smallint;
  v_due_min smallint;
  v_matched uuid;
BEGIN
  -- Compute due_date: 48 hours from now
  v_due_date := NOW() + interval '48 hours';
  v_due_dow  := EXTRACT(DOW FROM v_due_date)::smallint;
  -- slot: start_min = 0 (midnight), end_min = 1440 (covers full day)
  v_due_min  := 0;

  -- Create task
  INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
  VALUES (v_task_id, '11111111-1111-1111-1111-111111111111', 'Blocked Date Test Task', 'Desc', 'Criteria', v_due_date, 'open');

  -- Give both referees availability covering this DOW, full day
  INSERT INTO public.referee_available_time_slots (user_id, dow, start_min, end_min, is_active)
  VALUES
    ('22222222-2222-2222-2222-222222222222', v_due_dow, 0, 1440, true),
    ('33333333-3333-3333-3333-333333333333', v_due_dow, 0, 1440, true);

  -- Block referee B on the due_date
  INSERT INTO public.referee_blocked_dates (user_id, start_date, end_date, reason)
  VALUES (
    '22222222-2222-2222-2222-222222222222',
    (v_due_date AT TIME ZONE 'UTC')::date,
    (v_due_date AT TIME ZONE 'UTC')::date,
    'Test block'
  );

  -- Insert a pending request and trigger matching
  INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status)
  VALUES (gen_random_uuid(), v_task_id, 'standard', 'pending')
  RETURNING id INTO v_request_id;

  -- After INSERT trigger fires process_matching, check result
  SELECT matched_referee_id INTO v_matched
  FROM public.task_referee_requests
  WHERE id = v_request_id;

  ASSERT v_matched IS NOT NULL, 'Test 5 FAILED: should have matched a referee';
  ASSERT v_matched = '33333333-3333-3333-3333-333333333333',
    'Test 5 FAILED: should have matched referee C (33...), not blocked referee B (22...). Got: ' || v_matched::text;

  RAISE NOTICE 'Test 5 PASSED: blocked referee B excluded; referee C matched';
END $$;


-- =============================================================================
-- Test 6: cancel_referee_assignment — happy path with re-match
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 6: cancel_referee_assignment happy path'
\echo '=========================================='

-- Setup for Test 6
DO $$
DECLARE
  v_task_id uuid := 'aaaaaaaa-0006-0000-0000-000000000000';
  v_request_id uuid := 'bbbbbbbb-0006-0000-0000-000000000000';
  v_due_date timestamptz;
  v_due_dow smallint;
BEGIN
  -- due_date: 48 hours from now (well past cancel_deadline of 12h)
  v_due_date := NOW() + interval '48 hours';
  v_due_dow  := EXTRACT(DOW FROM v_due_date)::smallint;

  -- Store due_date for later assertions
  PERFORM set_config('app.test6_due_date', v_due_date::text, true);
  PERFORM set_config('app.test6_due_dow', v_due_dow::text, true);

  -- Create task (status=open, future due date)
  INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
  VALUES (v_task_id, '11111111-1111-1111-1111-111111111111', 'Cancel Happy Path Task', 'Desc', 'Criteria', v_due_date, 'open');

  -- Give both B and C availability for this DOW
  INSERT INTO public.referee_available_time_slots (user_id, dow, start_min, end_min, is_active)
  VALUES
    ('22222222-2222-2222-2222-222222222222', v_due_dow, 0, 1440, true),
    ('33333333-3333-3333-3333-333333333333', v_due_dow, 0, 1440, true)
  ON CONFLICT (user_id, dow, start_min) DO NOTHING;

  -- Manually set up: request already accepted by referee B, judgement created
  INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
  VALUES (v_request_id, v_task_id, 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

  INSERT INTO public.judgements (id, status)
  VALUES (v_request_id, 'awaiting_evidence');

  -- Lock 1 point for the task (simulating original matching)
  UPDATE public.point_wallets SET locked = locked + 1 WHERE user_id = '11111111-1111-1111-1111-111111111111';
END $$;

-- Act as referee B — set auth context outside DO block
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

-- Call cancel and store result
SELECT set_config('app.test6_result',
  public.cancel_referee_assignment('bbbbbbbb-0006-0000-0000-000000000000')::text,
  true);

-- Verify results
DO $$
DECLARE
  v_request_id uuid := 'bbbbbbbb-0006-0000-0000-000000000000';
  v_result json;
  v_new_request_id uuid;
  v_new_status text;
BEGIN
  v_result := current_setting('app.test6_result')::json;

  -- Check result
  ASSERT (v_result->>'success')::boolean = true,
    'Test 6 FAILED: cancel should succeed. Error: ' || COALESCE(v_result->>'error', 'none');

  -- Old request should be cancelled
  ASSERT (SELECT status::text FROM public.task_referee_requests WHERE id = v_request_id) = 'cancelled',
    'Test 6 FAILED: old request should be cancelled';

  -- Old judgement should be deleted
  ASSERT (SELECT COUNT(*) FROM public.judgements WHERE id = v_request_id) = 0,
    'Test 6 FAILED: old judgement should be deleted';

  -- New request should exist and be matched to referee C
  v_new_request_id := (v_result->>'new_request_id')::uuid;
  ASSERT v_new_request_id IS NOT NULL, 'Test 6 FAILED: new_request_id should be returned';

  v_new_status := (v_result->>'new_request_status');
  ASSERT v_new_status = 'accepted',
    'Test 6 FAILED: new request should be accepted (matched to C). Got: ' || v_new_status;

  ASSERT (SELECT matched_referee_id FROM public.task_referee_requests WHERE id = v_new_request_id)
    = '33333333-3333-3333-3333-333333333333',
    'Test 6 FAILED: new request should be matched to referee C';

  RAISE NOTICE 'Test 6 PASSED: cancel happy path — old cancelled, judgement deleted, re-matched to C';
END $$;


-- =============================================================================
-- Test 7: cancel_referee_assignment — rejected past cancel deadline
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 7: cancel past cancel deadline rejected'
\echo '=========================================='

-- Setup for Test 7
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES (
  'aaaaaaaa-0007-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'Past Deadline Task', 'Desc', 'Criteria',
  -- due_date only 6 hours from now: within the 12h cancel_deadline_hours window
  NOW() + interval '6 hours',
  'open'
);

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES (
  'bbbbbbbb-0007-0000-0000-000000000000',
  'aaaaaaaa-0007-0000-0000-000000000000',
  'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now()
);

INSERT INTO public.judgements (id, status)
VALUES ('bbbbbbbb-0007-0000-0000-000000000000', 'awaiting_evidence');

-- Act as referee B
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

SELECT set_config('app.test7_result',
  public.cancel_referee_assignment('bbbbbbbb-0007-0000-0000-000000000000')::text,
  true);

DO $$
DECLARE
  v_result json;
BEGIN
  v_result := current_setting('app.test7_result')::json;

  ASSERT (v_result->>'success')::boolean = false,
    'Test 7 FAILED: cancel should fail when past cancel deadline';
  ASSERT v_result->>'error' LIKE '%Cancel deadline has passed%',
    'Test 7 FAILED: error message should mention cancel deadline. Got: ' || COALESCE(v_result->>'error', 'null');

  -- Request should still be 'accepted'
  ASSERT (SELECT status::text FROM public.task_referee_requests WHERE id = 'bbbbbbbb-0007-0000-0000-000000000000') = 'accepted',
    'Test 7 FAILED: request status should remain accepted after failed cancel';

  RAISE NOTICE 'Test 7 PASSED: cancel rejected past deadline (error: %)', v_result->>'error';
END $$;


-- =============================================================================
-- Test 8: Cancelled referee excluded from re-matching (double-cancel → pending)
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 8: Double-cancel leads to pending (no referees left)'
\echo '=========================================='

-- Setup for Test 8
DO $$
DECLARE
  v_task_id uuid := 'aaaaaaaa-0008-0000-0000-000000000000';
  v_request_b_id uuid := 'bbbbbbbb-0008-0000-0000-000000000000';
  v_due_date timestamptz;
  v_due_dow smallint;
BEGIN
  -- due_date: 48 hours from now (well past 12h cancel deadline)
  v_due_date := NOW() + interval '48 hours';
  v_due_dow  := EXTRACT(DOW FROM v_due_date)::smallint;

  -- Create task
  INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
  VALUES (v_task_id, '11111111-1111-1111-1111-111111111111', 'Double Cancel Task', 'Desc', 'Criteria', v_due_date, 'open');

  -- Both B and C are available
  INSERT INTO public.referee_available_time_slots (user_id, dow, start_min, end_min, is_active)
  VALUES
    ('22222222-2222-2222-2222-222222222222', v_due_dow, 0, 1440, true),
    ('33333333-3333-3333-3333-333333333333', v_due_dow, 0, 1440, true)
  ON CONFLICT (user_id, dow, start_min) DO NOTHING;

  -- Manually assign request to referee B
  INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
  VALUES (v_request_b_id, v_task_id, 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

  INSERT INTO public.judgements (id, status)
  VALUES (v_request_b_id, 'awaiting_evidence');

  -- Lock 1 point for original matching
  UPDATE public.point_wallets SET locked = locked + 1 WHERE user_id = '11111111-1111-1111-1111-111111111111';
END $$;

-- === Step 1: Referee B cancels → should re-match to C ===
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

SELECT set_config('app.test8_result_b',
  public.cancel_referee_assignment('bbbbbbbb-0008-0000-0000-000000000000')::text,
  true);

DO $$
DECLARE
  v_result_b json;
  v_new_request_after_b_id uuid;
  v_new_status_after_b text;
BEGIN
  v_result_b := current_setting('app.test8_result_b')::json;

  ASSERT (v_result_b->>'success')::boolean = true,
    'Test 8 step 1 FAILED: B cancel should succeed. Error: ' || COALESCE(v_result_b->>'error', 'none');

  v_new_request_after_b_id := (v_result_b->>'new_request_id')::uuid;
  v_new_status_after_b := v_result_b->>'new_request_status';

  ASSERT v_new_status_after_b = 'accepted',
    'Test 8 step 1 FAILED: after B cancels, should match to C. Status: ' || v_new_status_after_b;

  ASSERT (SELECT matched_referee_id FROM public.task_referee_requests WHERE id = v_new_request_after_b_id)
    = '33333333-3333-3333-3333-333333333333',
    'Test 8 step 1 FAILED: new request should be matched to C';

  -- process_matching already created judgement for C's request
  ASSERT (SELECT COUNT(*) FROM public.judgements WHERE id = v_new_request_after_b_id) = 1,
    'Test 8 step 1 FAILED: judgement should be created for C request';

  -- Store C's request id for next step
  PERFORM set_config('app.test8_request_c_id', v_new_request_after_b_id::text, true);

  RAISE NOTICE 'Test 8 step 1 PASSED: B cancelled, C matched';
END $$;

-- === Step 2: Referee C cancels → no available referees (B excluded) → stays pending ===
SELECT set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333"}', true);

SELECT set_config('app.test8_result_c',
  public.cancel_referee_assignment(current_setting('app.test8_request_c_id')::uuid)::text,
  true);

DO $$
DECLARE
  v_result_c json;
  v_new_request_after_c_id uuid;
  v_new_status_after_c text;
BEGIN
  v_result_c := current_setting('app.test8_result_c')::json;

  ASSERT (v_result_c->>'success')::boolean = true,
    'Test 8 step 2 FAILED: C cancel should succeed. Error: ' || COALESCE(v_result_c->>'error', 'none');

  v_new_request_after_c_id := (v_result_c->>'new_request_id')::uuid;
  v_new_status_after_c := v_result_c->>'new_request_status';

  -- B was previously cancelled for this task. B and C are the only referees.
  -- With both excluded, no referee is available → new request stays 'pending'
  ASSERT v_new_status_after_c = 'pending',
    'Test 8 step 2 FAILED: after C cancels with no referees left, status should be pending. Got: ' || v_new_status_after_c;

  ASSERT (SELECT matched_referee_id FROM public.task_referee_requests WHERE id = v_new_request_after_c_id) IS NULL,
    'Test 8 step 2 FAILED: pending request should have no matched_referee_id';

  RAISE NOTICE 'Test 8 PASSED: B cancels → C matched; C cancels → pending (no referees left)';
END $$;


-- =============================================================================
-- Test 9: process_pending_requests — expire pending request + refund points
-- =============================================================================
\echo ''
\echo '=========================================='
\echo ' Test 9: process_pending_requests expire + refund'
\echo '=========================================='

-- Reset auth context to postgres for setup
SELECT set_config('request.jwt.claims', '{}', true);

-- Setup for Test 9
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES (
  'aaaaaaaa-0009-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'Expire Test Task', 'Desc', 'Criteria',
  -- due_date within rematch_cutoff_hours (14h) from now → will be expired
  NOW() + interval '13 hours',
  'open'
);

-- Insert pending request (no referee assigned)
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status)
VALUES ('bbbbbbbb-0009-0000-0000-000000000000', 'aaaaaaaa-0009-0000-0000-000000000000', 'standard', 'pending');

-- Simulate the locked point for this pending request
UPDATE public.point_wallets
SET locked = locked + 1
WHERE user_id = '11111111-1111-1111-1111-111111111111';

-- Record wallet state before process_pending_requests
SELECT set_config('app.test9_balance_before',
  (SELECT balance::text FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111'),
  true);
SELECT set_config('app.test9_locked_before',
  (SELECT locked::text FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111'),
  true);

-- Run process_pending_requests (SECURITY DEFINER, no auth context needed)
SELECT set_config('app.test9_result',
  public.process_pending_requests()::text,
  true);

DO $$
DECLARE
  v_request_id uuid := 'bbbbbbbb-0009-0000-0000-000000000000';
  v_result json;
  v_balance_before int;
  v_locked_before int;
  v_balance_after int;
  v_locked_after int;
BEGIN
  v_result := current_setting('app.test9_result')::json;
  v_balance_before := current_setting('app.test9_balance_before')::int;
  v_locked_before  := current_setting('app.test9_locked_before')::int;

  ASSERT (v_result->>'success')::boolean = true,
    'Test 9 FAILED: process_pending_requests should succeed. Error: ' || COALESCE(v_result->>'error', 'none');

  -- Request should be expired
  ASSERT (SELECT status::text FROM public.task_referee_requests WHERE id = v_request_id) = 'expired',
    'Test 9 FAILED: request status should be expired';

  -- Record wallet state after
  SELECT balance, locked INTO v_balance_after, v_locked_after
  FROM public.point_wallets
  WHERE user_id = '11111111-1111-1111-1111-111111111111';

  -- Locked should have decreased by 1 (refund via unlock_points)
  ASSERT v_locked_after = v_locked_before - 1,
    'Test 9 FAILED: locked should decrease by 1 after refund. Before: ' || v_locked_before || ', After: ' || v_locked_after;

  -- Balance should be unchanged (unlock_points does not reduce balance)
  ASSERT v_balance_after = v_balance_before,
    'Test 9 FAILED: balance should be unchanged after unlock. Before: ' || v_balance_before || ', After: ' || v_balance_after;

  -- Ledger entry for refund should exist
  ASSERT (SELECT COUNT(*) FROM public.point_ledger
    WHERE user_id = '11111111-1111-1111-1111-111111111111'
    AND reason = 'matching_refund') >= 1,
    'Test 9 FAILED: should have matching_refund ledger entry';

  RAISE NOTICE 'Test 9 PASSED: process_pending_requests expired request and refunded locked points';
END $$;


-- =============================================================================
-- Cleanup
-- =============================================================================
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
