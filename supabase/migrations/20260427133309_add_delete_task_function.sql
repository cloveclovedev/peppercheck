set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_task(p_task_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_current_status public.task_status;
    v_tasker_id uuid;
BEGIN
    -- 1. Check Existence and capture state
    SELECT status, tasker_id INTO v_current_status, v_tasker_id
    FROM public.tasks
    WHERE id = p_task_id;

    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    -- 2. Check Ownership
    IF v_tasker_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to delete this task';
    END IF;

    -- 3. Check Status (only drafts can be deleted)
    IF v_current_status != 'draft' THEN
        RAISE EXCEPTION 'Only draft tasks can be deleted';
    END IF;

    -- 4. Delete (FK CASCADE handles task_referee_requests / task_evidences / reports if any)
    DELETE FROM public.tasks WHERE id = p_task_id;
END;
$function$
;


