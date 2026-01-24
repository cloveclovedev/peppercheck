CREATE OR REPLACE FUNCTION public.create_task(
    title text,
    description text DEFAULT NULL::text,
    criteria text DEFAULT NULL::text,
    due_date timestamp with time zone DEFAULT NULL::timestamp with time zone,
    status public.task_status DEFAULT 'draft'::public.task_status,
    referee_requests jsonb[] DEFAULT NULL::jsonb[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    new_task_id uuid;
BEGIN
    -- Validate inputs based on status
    PERFORM public.validate_task_inputs(status, title, description, criteria, due_date, referee_requests);

    -- Shared Logic Validation (Business Logic: Due Date, Points) for Open tasks
    IF status = 'open' THEN
        PERFORM public.validate_task_open_requirements(auth.uid(), due_date, referee_requests);
    END IF;

    -- Insert into tasks
    INSERT INTO public.tasks (
        title,
        description,
        criteria,
        due_date,
        status,
        tasker_id
    )
    VALUES (
        title,
        description,
        criteria,
        due_date,
        status,
        auth.uid()
    )
    RETURNING id INTO new_task_id;

    -- Handle Referee Requests if provided (Only for Open tasks)
    IF status = 'open' THEN
        PERFORM public.create_task_referee_requests_from_json(new_task_id, referee_requests);
    END IF;

    RETURN new_task_id;
END;
$$;
