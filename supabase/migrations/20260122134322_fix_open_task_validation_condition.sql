set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.validate_task_inputs(p_status text, p_title text, p_description text DEFAULT NULL::text, p_criteria text DEFAULT NULL::text, p_due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_referee_requests jsonb[] DEFAULT NULL::jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    IF p_status = 'draft' THEN
        IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for draft tasks';
        END IF;
    ELSIF p_status = 'open' THEN
        IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for open tasks';
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
$function$
;


