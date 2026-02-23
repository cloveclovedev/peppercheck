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
    v_judgement_status text;
BEGIN
    -- 1. Identify Recipient (Referee) and current judgement status
    SELECT trr.matched_referee_id, j.status::text
    INTO v_referee_id, v_judgement_status
    FROM public.task_referee_requests trr
    JOIN public.judgements j ON j.id = trr.id
    WHERE trr.task_id = NEW.task_id;

    IF v_referee_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Determine Event Key
    IF TG_OP = 'INSERT' THEN
        v_notification_key := 'notification_evidence_submitted_referee';
    ELSIF TG_OP = 'UPDATE' THEN
        -- During resubmission, evidence is updated while judgement is still 'rejected'.
        -- The judgement status change trigger handles the resubmission notification.
        IF v_judgement_status = 'rejected' THEN
            RETURN NEW;
        END IF;
        v_notification_key := 'notification_evidence_updated_referee';
    END IF;

    -- 3. Identify Task Details
    SELECT title INTO v_task_title FROM public.tasks WHERE id = NEW.task_id;

    -- 4. Invoke Notification
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

DROP TRIGGER IF EXISTS on_task_evidences_upserted_notify_referee ON public.task_evidences;

CREATE TRIGGER on_task_evidences_upserted_notify_referee
    AFTER INSERT OR UPDATE ON public.task_evidences
    FOR EACH ROW
    EXECUTE FUNCTION public.on_task_evidences_upserted_notify_referee();
