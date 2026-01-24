CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout_from_referee(p_judgement_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement_record public.judgements%ROWTYPE;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Get judgement details and verify it exists and is in evidence_timeout status
    SELECT * INTO v_judgement_record
    FROM public.judgements 
    WHERE id = p_judgement_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;
    
    IF v_judgement_record.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement is not in evidence_timeout status';
    END IF;
    
    IF v_judgement_record.is_evidence_timeout_confirmed = true THEN
        RAISE EXCEPTION 'Evidence timeout already confirmed';
    END IF;
    
    -- Update judgement to mark evidence timeout as confirmed
    UPDATE public.judgements 
    SET 
        is_evidence_timeout_confirmed = true,
        updated_at = v_now
    WHERE id = p_judgement_id;
    
    RETURN json_build_object(
        'success', true,
        'judgement_id', p_judgement_id,
        'confirmed_at', v_now
    );

END;
$$;

ALTER FUNCTION public.confirm_evidence_timeout_from_referee(p_judgement_id uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_evidence_timeout_from_referee(p_judgement_id uuid) IS 'Allows referee to confirm evidence timeout by setting is_evidence_timeout_confirmed to true. Returns JSON on success, raises exception on error. Triggers system processes to close the task_referee_request.';
