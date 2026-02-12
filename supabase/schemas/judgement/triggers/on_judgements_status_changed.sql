-- Trigger function to notify relevant users when judgement status changes
CREATE OR REPLACE FUNCTION public.on_judgements_status_changed()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_tasker_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_notification_key text;
BEGIN
    -- Early return if status did not change
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Resolve task info via task_referee_requests
    SELECT t.id, t.tasker_id, t.title
    INTO v_task_id, v_tasker_id, v_task_title
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Determine notification based on new status
    CASE NEW.status
        WHEN 'approved' THEN
            v_notification_key := 'notification_judgement_approved';
        WHEN 'rejected' THEN
            v_notification_key := 'notification_judgement_rejected';
        ELSE
            -- Other status changes: no notification for now (future extension point)
            RETURN NEW;
    END CASE;

    -- Send notification to tasker
    PERFORM public.notify_event(
        v_tasker_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.on_judgements_status_changed() OWNER TO postgres;

-- Create Trigger
DROP TRIGGER IF EXISTS on_judgements_status_changed ON public.judgements;

CREATE TRIGGER on_judgements_status_changed
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.on_judgements_status_changed();
