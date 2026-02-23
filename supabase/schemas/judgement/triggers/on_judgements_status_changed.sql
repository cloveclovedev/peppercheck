-- Trigger function to notify relevant users when judgement status changes
CREATE OR REPLACE FUNCTION public.on_judgements_status_changed()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_notification_key text;
    v_recipient_id uuid;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Resolve task info via task_referee_requests
    SELECT t.id, t.tasker_id, t.title, trr.matched_referee_id
    INTO v_task_id, v_tasker_id, v_task_title, v_referee_id
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
            v_recipient_id := v_tasker_id;
        WHEN 'rejected' THEN
            v_notification_key := 'notification_judgement_rejected';
            v_recipient_id := v_tasker_id;
        WHEN 'in_review' THEN
            -- Resubmission: rejected → in_review with reopen_count > 0
            IF OLD.status = 'rejected' AND NEW.reopen_count > 0 THEN
                v_notification_key := 'notification_evidence_resubmitted';
                v_recipient_id := v_referee_id;
            ELSE
                RETURN NEW;
            END IF;
        ELSE
            RETURN NEW;
    END CASE;

    -- Send notification
    PERFORM public.notify_event(
        v_recipient_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.on_judgements_status_changed() OWNER TO postgres;

DROP TRIGGER IF EXISTS on_judgements_status_changed ON public.judgements;

CREATE TRIGGER on_judgements_status_changed
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.on_judgements_status_changed();
