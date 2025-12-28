CREATE OR REPLACE FUNCTION public.validate_task_inputs(
    p_status text,
    p_title text,
    p_description text DEFAULT NULL,
    p_criteria text DEFAULT NULL,
    p_due_date timestamp with time zone DEFAULT NULL,
    p_referee_requests jsonb[] DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_status = 'draft' THEN
        IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for draft tasks';
        END IF;
    ELSIF p_status = 'open' THEN
        IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for open tasks';
        END IF;
        IF p_description IS NULL OR length(trim(p_description)) = 0 THEN
             RAISE EXCEPTION 'Description is required for open tasks';
        END IF;
        IF p_criteria IS NULL OR length(trim(p_criteria)) = 0 THEN
             RAISE EXCEPTION 'Criteria is required for open tasks';
        END IF;
        IF p_due_date IS NULL THEN
             RAISE EXCEPTION 'Due date is required for open tasks';
        END IF;
        IF p_referee_requests IS NULL OR array_length(p_referee_requests, 1) IS NULL THEN
             RAISE EXCEPTION 'At least one referee request is required for open tasks';
        END IF;
    END IF;
END;
$$;

ALTER FUNCTION public.validate_task_inputs(text, text, text, text, timestamp with time zone, jsonb[]) OWNER TO postgres;
