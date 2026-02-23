-- Function + Trigger: Send notification when judgement is confirmed
-- Branches on is_auto_confirmed to determine notification type
CREATE OR REPLACE FUNCTION public.notify_judgement_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
BEGIN
    -- Get task and user details
    SELECT t.tasker_id, trr.matched_referee_id, trr.task_id, t.title
    INTO v_tasker_id, v_referee_id, v_task_id, v_task_title
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RAISE WARNING 'notify_judgement_confirmed: request not found for judgement %', NEW.id;
        RETURN NEW;
    END IF;

    IF NEW.is_auto_confirmed THEN
        -- Auto-confirm: notify both tasker and referee
        PERFORM public.notify_event(
            v_tasker_id,
            'notification_auto_confirm_tasker',
            ARRAY[v_task_title],
            jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
        );

        PERFORM public.notify_event(
            v_referee_id,
            'notification_auto_confirm_referee',
            ARRAY[v_task_title],
            jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
        );
    -- ELSE: manual confirm notification (future implementation)
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_judgement_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_judgement_confirmed_notify
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND OLD.is_confirmed = false)
    EXECUTE FUNCTION public.notify_judgement_confirmed();

COMMENT ON TRIGGER on_judgement_confirmed_notify ON public.judgements IS 'Sends notification when judgement is confirmed. Branches on is_auto_confirmed for auto-confirm vs manual confirm notifications.';
