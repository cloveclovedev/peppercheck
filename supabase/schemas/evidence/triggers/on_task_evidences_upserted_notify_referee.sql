-- Trigger function to notify referee when evidence is submitted or updated
CREATE OR REPLACE FUNCTION public.on_task_evidences_upserted_notify_referee()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_referee_id uuid;
    v_task_title text;
    v_notification_key text;
BEGIN
    -- 1. Identify Recipient (Referee)
    -- Join judgements and task_referee_requests to find the active referee for the task
    SELECT trr.matched_referee_id
    INTO v_referee_id
    FROM public.task_referee_requests trr
    JOIN public.judgements j ON j.id = trr.id
    WHERE trr.task_id = NEW.task_id;

    -- If no referee found (e.g. evidence submitted before matching? unlikely but safe check), exit
    IF v_referee_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Identify Task Details
    SELECT title INTO v_task_title FROM public.tasks WHERE id = NEW.task_id;

    -- 3. Determine Event Key
    IF TG_OP = 'INSERT' THEN
        v_notification_key := 'notification_evidence_submitted';
    ELSIF TG_OP = 'UPDATE' THEN
        -- Only notify if the status or description essentially changed, or just always notify on update?
        -- For now, simple update notification.
        v_notification_key := 'notification_evidence_updated';
    END IF;

    -- 4. Invoke Notification
    -- data payload includes task_id for navigation
    PERFORM public.notify_event(
        v_referee_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', NEW.task_id)
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.on_task_evidences_upserted_notify_referee() OWNER TO postgres;

-- Create Trigger
DROP TRIGGER IF EXISTS on_task_evidences_upserted_notify_referee ON public.task_evidences;

CREATE TRIGGER on_task_evidences_upserted_notify_referee
    AFTER INSERT OR UPDATE ON public.task_evidences
    FOR EACH ROW
    EXECUTE FUNCTION public.on_task_evidences_upserted_notify_referee();
