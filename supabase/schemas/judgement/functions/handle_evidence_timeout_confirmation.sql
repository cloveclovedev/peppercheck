CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_task_id UUID;
    v_referee_id UUID;
    v_request_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Only proceed if is_evidence_timeout_confirmed was changed from false to true
    -- and the judgement status is evidence_timeout
    IF NEW.is_evidence_timeout_confirmed = true 
       AND OLD.is_evidence_timeout_confirmed = false 
       AND NEW.status = 'evidence_timeout' THEN
        
        -- Get the task_id and referee_id from the judgement
        v_task_id := NEW.task_id;
        v_referee_id := NEW.referee_id;
        
        -- Previously triggered billing logic here:
        -- PERFORM public.start_billing(trr.id) ...
        -- Billing system has been removed. 
        -- Task closure is handled by close_task_if_all_judgements_confirmed trigger if needed.
        
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the original update
        RAISE WARNING 'Error in handle_evidence_timeout_confirmation: %', SQLERRM;
        -- Return NEW to allow the original judgement update to succeed
        RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_evidence_timeout_confirmation() OWNER TO postgres;

COMMENT ON FUNCTION public.handle_evidence_timeout_confirmation() IS 'Automatically closes the specific task_referee_request (matched to the referee) when referee confirms evidence timeout by setting is_evidence_timeout_confirmed to true';
