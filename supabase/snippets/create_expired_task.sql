-- Snippet to create a task with expired due_date for testing evidence timeout flow.
--
-- Usage:
--   1. Set v_tasker_id and v_referee_id below to actual user IDs from your local DB
--   2. Run this snippet via Supabase SQL editor or psql
--   3. The script creates the task, triggers timeout detection, and shows results
--
-- Prerequisites:
--   - Both users must exist in profiles table
--   - Tasker must have sufficient points (at least 1 point available)

DO $$
DECLARE
    -- ========================================
    -- CONFIGURE THESE VALUES
    -- ========================================
    v_tasker_id uuid := '00000000-0000-0000-0000-000000000000';  -- Replace with actual tasker user ID
    v_referee_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual referee user ID
    -- ========================================

    v_task_id uuid;
    v_request_id uuid;
    v_result json;
BEGIN
    -- 1. Create task with due_date in the past
    INSERT INTO public.tasks (tasker_id, title, description, criteria, due_date, status)
    VALUES (
        v_tasker_id,
        '[TEST] Expired task ' || to_char(now(), 'HH24:MI:SS'),
        'Test task for evidence timeout verification',
        'Test criteria',
        now() - interval '1 day',
        'open'
    )
    RETURNING id INTO v_task_id;
    RAISE NOTICE 'Created task: %', v_task_id;

    -- 2. Create accepted referee request
    INSERT INTO public.task_referee_requests (task_id, matching_strategy, status, matched_referee_id, responded_at)
    VALUES (
        v_task_id,
        'standard',
        'accepted',
        v_referee_id,
        now() - interval '2 days'
    )
    RETURNING id INTO v_request_id;
    RAISE NOTICE 'Created referee request: %', v_request_id;

    -- 3. Create judgement in awaiting_evidence status
    INSERT INTO public.judgements (id, status)
    VALUES (v_request_id, 'awaiting_evidence');
    RAISE NOTICE 'Created judgement: %', v_request_id;

    -- 4. Lock points for the tasker (simulating what happens when task opens)
    PERFORM public.lock_points(
        v_tasker_id,
        public.get_point_for_matching_strategy('standard'::public.matching_strategy),
        'matching_locked'::public.point_reason,
        'Test lock for expired task',
        v_request_id
    );
    RAISE NOTICE 'Locked points for tasker';

    -- 5. Run evidence timeout detection (triggers settlement via on_evidence_timeout_settle)
    v_result := public.detect_and_handle_evidence_timeouts();
    RAISE NOTICE 'Timeout detection result: %', v_result;

    -- 6. Show final state
    RAISE NOTICE '--- RESULTS ---';
    RAISE NOTICE 'Task ID: %', v_task_id;
    RAISE NOTICE 'Check task_detail screen for tasker to see timeout confirmation UI';
END $$;

-- Verify: Check the created task and judgement state
SELECT
    t.id AS task_id,
    t.title,
    t.status AS task_status,
    t.due_date,
    j.status AS judgement_status,
    j.is_evidence_timeout_confirmed,
    j.is_confirmed,
    trr.status AS request_status
FROM public.tasks t
JOIN public.task_referee_requests trr ON trr.task_id = t.id
JOIN public.judgements j ON j.id = trr.id
WHERE t.title LIKE '[TEST] Expired task%'
ORDER BY t.created_at DESC
LIMIT 5;
