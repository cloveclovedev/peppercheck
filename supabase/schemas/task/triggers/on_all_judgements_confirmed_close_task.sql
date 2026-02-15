-- Function + Trigger: Close task when all judgements are confirmed
CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_task_id uuid;
BEGIN
    -- Get the task_id for this judgement
    SELECT trr.task_id INTO v_task_id
    FROM public.task_referee_requests trr
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Concurrency protection: lock the task row
    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    -- Check if all judgements for this task are confirmed
    IF NOT EXISTS (
        SELECT 1 FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        WHERE trr.task_id = v_task_id AND j.is_confirmed = false
    ) THEN
        UPDATE public.tasks
        SET status = 'closed'::public.task_status
        WHERE id = v_task_id;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.close_task_if_all_judgements_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_all_judgements_confirmed_close_task
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND OLD.is_confirmed = false)
    EXECUTE FUNCTION public.close_task_if_all_judgements_confirmed();

COMMENT ON TRIGGER on_all_judgements_confirmed_close_task ON public.judgements IS 'Closes the task when all judgements for that task have is_confirmed = true. Separates referee-side closure (request) from tasker-side closure (task).';
