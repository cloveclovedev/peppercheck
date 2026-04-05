CREATE OR REPLACE FUNCTION public.detect_judgement_deadline_warnings() RETURNS json
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
            trr.matched_referee_id AS user_id,
            t.id AS task_id,
            t.title AS task_title,
            t.due_date + INTERVAL '3 hours' AS deadline,
            rm.reminder_minutes,
            p.timezone AS user_timezone
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        JOIN public.notification_settings ns ON ns.user_id = trr.matched_referee_id
        JOIN public.profiles p ON p.id = trr.matched_referee_id
        CROSS JOIN LATERAL unnest(ns.judgement_reminder_minutes) AS rm(reminder_minutes)
        LEFT JOIN public.notification_sent_log nsl ON
            nsl.judgement_id = j.id
            AND nsl.notification_key = 'notification_judgement_deadline_warning_referee'
            AND nsl.reminder_minutes = rm.reminder_minutes
        WHERE j.status = 'in_review'
            AND t.due_date IS NOT NULL
            AND v_now >= (t.due_date + INTERVAL '3 hours') - (rm.reminder_minutes || ' minutes')::interval
            AND v_now <= t.due_date + INTERVAL '3 hours'
            AND nsl.id IS NULL
    LOOP
        PERFORM public.send_deadline_reminder(
            v_rec.judgement_id,
            v_rec.user_id,
            'notification_judgement_deadline_warning_referee',
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

ALTER FUNCTION public.detect_judgement_deadline_warnings() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_judgement_deadline_warnings IS 'Scans for judgements approaching review deadline (due_date + 3h) and sends reminder notifications to referees. Called by pg_cron every minute.';
