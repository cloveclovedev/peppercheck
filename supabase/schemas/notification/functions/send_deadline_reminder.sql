CREATE OR REPLACE FUNCTION public.send_deadline_reminder(
    p_judgement_id uuid,
    p_user_id uuid,
    p_notification_key text,
    p_reminder_minutes integer,
    p_deadline timestamptz,
    p_task_id uuid,
    p_task_title text,
    p_user_timezone text
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
DECLARE
    v_row_count integer;
    v_formatted_time text;
BEGIN
    -- Idempotency: attempt insert, skip if already sent
    INSERT INTO public.notification_sent_log (judgement_id, notification_key, reminder_minutes)
    VALUES (p_judgement_id, p_notification_key, p_reminder_minutes)
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    IF v_row_count = 0 THEN
        RETURN;
    END IF;

    -- Format deadline time in user's timezone
    v_formatted_time := TO_CHAR(
        p_deadline AT TIME ZONE COALESCE(p_user_timezone, 'UTC'),
        'HH24:MI'
    );

    -- Dispatch notification via notify_event
    PERFORM public.notify_event(
        p_user_id,
        p_notification_key,
        ARRAY[p_task_title, v_formatted_time],
        jsonb_build_object('task_id', p_task_id)
    );
END;
$$;

ALTER FUNCTION public.send_deadline_reminder(uuid, uuid, text, integer, timestamptz, uuid, text, text) OWNER TO postgres;

COMMENT ON FUNCTION public.send_deadline_reminder IS 'Idempotent helper: inserts a notification_sent_log record and dispatches a deadline reminder via notify_event. Skips silently if the reminder was already sent.';
