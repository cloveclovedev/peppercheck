CREATE OR REPLACE FUNCTION public.validate_evidence_due_date() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_due_date TIMESTAMP WITH TIME ZONE;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Get task due_date
    SELECT t.due_date INTO v_due_date
    FROM public.tasks t
    WHERE t.id = NEW.task_id;
    
    -- Check if due date has passed
    IF v_due_date IS NOT NULL AND v_now > v_due_date THEN
        RAISE EXCEPTION 'Evidence cannot be submitted after due date.';
    END IF;
    
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.validate_evidence_due_date() OWNER TO postgres;

COMMENT ON FUNCTION public.validate_evidence_due_date() IS 'Validates that evidence cannot be submitted or updated after the task due date has passed. Raises exception if due date validation fails.';
