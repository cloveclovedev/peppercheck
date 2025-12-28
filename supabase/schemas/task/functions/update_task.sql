CREATE OR REPLACE FUNCTION public.update_task(
    p_task_id uuid,
    p_title text,
    p_description text DEFAULT NULL,
    p_criteria text DEFAULT NULL,
    p_due_date timestamp with time zone DEFAULT NULL,
    p_status text DEFAULT 'draft'::text,
    p_referee_requests jsonb[] DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_current_status text;
    v_tasker_id uuid;
    v_req jsonb;
    v_strategy text;
    v_pref_referee uuid;
BEGIN
    -- 1. Check Existence, Ownership, and Current Status
    SELECT status, tasker_id INTO v_current_status, v_tasker_id
    FROM public.tasks
    WHERE id = p_task_id;

    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    IF v_tasker_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to update this task';
    END IF;

    IF v_current_status != 'draft' THEN
        RAISE EXCEPTION 'Only draft tasks can be updated';
    END IF;

    -- 2. Validate Inputs based on Target Status
    -- 2. Validate Inputs based on Target Status
    IF p_status = 'draft' OR p_status = 'open' THEN
        PERFORM public.validate_task_inputs(p_status, p_title, p_description, p_criteria, p_due_date, p_referee_requests);

        -- Shared Logic Validation (Business Logic: Due Date, Points) for Open tasks
        IF p_status = 'open' THEN
            PERFORM public.validate_task_open_requirements(auth.uid(), p_due_date, p_referee_requests);
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid status transition. Can only update to Draft or Open.';
    END IF;

    -- 3. Update Task
    UPDATE public.tasks
    SET title = p_title,
        description = p_description,
        criteria = p_criteria,
        due_date = p_due_date,
        status = p_status,
        updated_at = now()
    WHERE id = p_task_id;

    -- 4. Handle Referee Requests (Only if transitioning to Open)
    IF p_status = 'open' THEN
        -- Theoretically a Draft task shouldn't have requests, but we clean up just in case
        -- to ensure "Replacement" logic.
        DELETE FROM public.task_referee_requests
        WHERE task_id = p_task_id AND status = 'pending';

        PERFORM public.create_task_referee_requests_from_json(p_task_id, p_referee_requests);
    END IF;

END;
$$;
