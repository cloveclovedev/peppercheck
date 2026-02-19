-- Test snippet: Creates a task with review timeout scenario
-- (Evidence submitted, referee hasn't reviewed, past due_date + 3h)
--
-- Usage: Set v_tasker_id and v_referee_id, then run in SQL editor.
-- After running, open the tasker's task detail screen to see the review timeout confirm UI.

DO $$
DECLARE
    v_tasker_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual tasker ID
    v_referee_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual referee ID
    v_task_id uuid;
    v_request_id uuid;
BEGIN
    -- 1. Create task with due_date 1 day ago
    INSERT INTO public.tasks (
        tasker_id, title, description, due_date, status
    ) VALUES (
        v_tasker_id,
        'Review Timeout Test Task',
        'This task is for testing review timeout.',
        now() - interval '1 day',
        'open'
    ) RETURNING id INTO v_task_id;

    -- 2. Create accepted referee request
    INSERT INTO public.task_referee_requests (
        task_id, matched_referee_id, status, matching_strategy, responded_at
    ) VALUES (
        v_task_id, v_referee_id, 'accepted', 'standard', now() - interval '2 days'
    ) RETURNING id INTO v_request_id;

    -- 3. Create judgement in in_review status (evidence was submitted)
    INSERT INTO public.judgements (
        id, status
    ) VALUES (
        v_request_id, 'in_review'
    );

    -- 4. Create evidence (so the task looks like evidence was submitted)
    INSERT INTO public.task_evidences (
        task_id, description
    ) VALUES (
        v_task_id, 'Test evidence for review timeout'
    );

    -- 5. Lock points for tasker
    PERFORM public.lock_points(
        v_tasker_id,
        public.get_point_for_matching_strategy('standard'::public.matching_strategy),
        'matching_lock'::public.point_reason,
        'Test lock for review timeout task',
        v_request_id
    );

    -- 6. Trigger review timeout detection
    PERFORM public.detect_and_handle_review_timeouts();

    RAISE NOTICE 'Created review timeout test: task_id=%, request_id=%', v_task_id, v_request_id;
END;
$$;

-- Verification query
SELECT
    t.id AS task_id,
    t.title,
    t.status AS task_status,
    j.status AS judgement_status,
    j.is_confirmed,
    trr.status AS request_status,
    pw.balance,
    pw.locked
FROM public.tasks t
JOIN public.task_referee_requests trr ON trr.task_id = t.id
JOIN public.judgements j ON j.id = trr.id
LEFT JOIN public.point_wallets pw ON pw.user_id = t.tasker_id
WHERE t.title = 'Review Timeout Test Task'
ORDER BY t.created_at DESC
LIMIT 1;
