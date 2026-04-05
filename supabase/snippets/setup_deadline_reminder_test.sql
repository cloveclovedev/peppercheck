-- Snippet to create a task approaching its evidence deadline for testing reminder notifications.
--
-- Usage:
--   1. Set v_tasker_id and v_referee_id below to actual user IDs from your local DB
--   2. Run this snippet via Supabase SQL editor or psql
--   3. The script creates a task with due_date 11 minutes from now
--   4. Wait ~1 minute for the cron job to detect and send the reminder
--   5. Check push notification on emulator and notification_sent_log table
--
-- Prerequisites:
--   - Both users must exist in profiles table
--   - Tasker must have sufficient points (at least 1 point available)
--   - Edge Functions must be serving (supabase functions serve)
--   - Vault secrets must be set (run setup_secrets.sql if not)

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
    v_due_date timestamptz;
    v_result json;
BEGIN
    v_due_date := now() + interval '11 minutes';

    -- 1. Create task with due_date 11 minutes from now
    INSERT INTO public.tasks (tasker_id, title, description, criteria, due_date, status)
    VALUES (
        v_tasker_id,
        '[TEST] Reminder test ' || to_char(now(), 'HH24:MI:SS'),
        'Test task for deadline reminder verification',
        'Test criteria',
        v_due_date,
        'open'
    )
    RETURNING id INTO v_task_id;
    RAISE NOTICE 'Created task: %', v_task_id;
    RAISE NOTICE 'Due date: % (11 minutes from now)', v_due_date;

    -- 2. Create accepted referee request
    INSERT INTO public.task_referee_requests (task_id, matching_strategy, status, matched_referee_id, responded_at)
    VALUES (
        v_task_id,
        'standard',
        'accepted',
        v_referee_id,
        now()
    )
    RETURNING id INTO v_request_id;
    RAISE NOTICE 'Created referee request: %', v_request_id;

    -- 3. Create judgement in awaiting_evidence status
    INSERT INTO public.judgements (id, status)
    VALUES (v_request_id, 'awaiting_evidence');
    RAISE NOTICE 'Created judgement: %', v_request_id;

    -- 4. Lock points for the tasker
    PERFORM public.lock_points(
        v_tasker_id,
        public.get_point_for_matching_strategy('standard'::public.matching_strategy),
        'matching_lock'::public.point_reason,
        'Test lock for reminder test',
        v_request_id
    );
    RAISE NOTICE 'Locked points for tasker';

    -- 5. Manually trigger detection (instead of waiting for cron)
    v_result := public.detect_evidence_deadline_warnings();
    RAISE NOTICE 'Detection result: %', v_result;

    RAISE NOTICE '';
    RAISE NOTICE '--- NEXT STEPS ---';
    RAISE NOTICE '1. Check notification_sent_log below for the reminder record';
    RAISE NOTICE '2. Check emulator for push notification (if Edge Functions are running)';
    RAISE NOTICE '3. Or wait ~1 minute for the cron job to auto-detect (already detected above)';
END $$;

-- Verify: Check notification_sent_log
SELECT
    nsl.judgement_id,
    nsl.notification_key,
    nsl.reminder_minutes,
    nsl.sent_at
FROM public.notification_sent_log nsl
ORDER BY nsl.sent_at DESC
LIMIT 5;

-- Verify: Check notification_settings for the tasker
SELECT
    ns.user_id,
    ns.evidence_reminder_minutes,
    ns.judgement_reminder_minutes,
    ns.auto_confirm_reminder_minutes
FROM public.notification_settings ns
LIMIT 5;

-- Verify: Check the created task state
SELECT
    t.id AS task_id,
    t.title,
    t.due_date,
    t.due_date - now() AS time_until_deadline,
    j.status AS judgement_status
FROM public.tasks t
JOIN public.task_referee_requests trr ON trr.task_id = t.id
JOIN public.judgements j ON j.id = trr.id
WHERE t.title LIKE '[TEST] Reminder test%'
ORDER BY t.created_at DESC
LIMIT 5;
