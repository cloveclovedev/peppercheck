-- Function + Trigger: Close task when all referee requests are closed
CREATE OR REPLACE FUNCTION public.close_task_if_all_requests_closed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_task_id uuid;
BEGIN
    v_task_id := NEW.task_id;

    -- Concurrency protection: lock the task row
    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    -- Check if all referee requests for this task are closed
    IF NOT EXISTS (
        SELECT 1 FROM public.task_referee_requests
        WHERE task_id = v_task_id AND status != 'closed'::public.referee_request_status
    ) THEN
        UPDATE public.tasks
        SET status = 'closed'::public.task_status
        WHERE id = v_task_id;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.close_task_if_all_requests_closed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_all_requests_closed_close_task
    AFTER UPDATE ON public.task_referee_requests
    FOR EACH ROW
    WHEN (NEW.status = 'closed' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.close_task_if_all_requests_closed();
