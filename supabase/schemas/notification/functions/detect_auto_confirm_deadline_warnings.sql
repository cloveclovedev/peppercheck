CREATE OR REPLACE FUNCTION public.detect_auto_confirm_deadline_warnings() RETURNS json
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
DECLARE
    v_now timestamptz;
    v_count integer := 0;
    v_rec record;
BEGIN
    v_now := NOW();

    FOR v_rec IN
        SELECT
            j.id AS judgement_id,
            t.tasker_id AS user_id,
            t.id AS task_id,
            t.title AS task_title,
            t.due_date + INTERVAL '3 days' AS deadline,
            rm.reminder_minutes,
            p.timezone AS user_timezone
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        JOIN public.notification_settings ns ON ns.user_id = t.tasker_id
        JOIN public.profiles p ON p.id = t.tasker_id
        CROSS JOIN LATERAL unnest(ns.auto_confirm_reminder_minutes) AS rm(reminder_minutes)
        LEFT JOIN public.notification_sent_log nsl ON
            nsl.judgement_id = j.id
            AND nsl.notification_key = 'notification_auto_confirm_deadline_warning_tasker'
            AND nsl.reminder_minutes = rm.reminder_minutes
        WHERE j.is_confirmed = false
            AND j.status IN ('approved', 'rejected', 'review_timeout', 'evidence_timeout')
            AND t.due_date IS NOT NULL
            AND v_now >= (t.due_date + INTERVAL '3 days') - (rm.reminder_minutes || ' minutes')::interval
            AND v_now <= t.due_date + INTERVAL '3 days'
            AND nsl.id IS NULL
    LOOP
        PERFORM public.send_deadline_reminder(
            v_rec.judgement_id,
            v_rec.user_id,
            'notification_auto_confirm_deadline_warning_tasker',
            v_rec.reminder_minutes,
            v_rec.deadline,
            v_rec.task_id,
            v_rec.task_title,
            v_rec.user_timezone
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'reminder_count', v_count,
        'processed_at', v_now
    );
END;
$$;

ALTER FUNCTION public.detect_auto_confirm_deadline_warnings() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_auto_confirm_deadline_warnings IS 'Scans for unconfirmed judgements approaching auto-confirm deadline (due_date + 3 days) and sends reminder notifications to taskers. Default OFF (auto_confirm_reminder_minutes is NULL). Called by pg_cron every minute.';
