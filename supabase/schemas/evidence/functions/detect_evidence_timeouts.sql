CREATE OR REPLACE FUNCTION public.detect_and_handle_evidence_timeouts() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_timeout_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have evidence timeout (due_date passed without evidence)
    -- Only update judgements that are still 'open' and past the due date with no evidence
    UPDATE public.judgements j
    SET 
        status = 'evidence_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    LEFT JOIN public.task_evidences te ON t.id = te.task_id
    WHERE j.id = trr.id
    AND j.status = 'awaiting_evidence' -- Changed from 'open' to 'awaiting_evidence' based on enum
    AND v_now > t.due_date
    AND te.id IS NULL; -- No evidence submitted

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'processed_at', v_now
        );
END;
$$;

ALTER FUNCTION public.detect_and_handle_evidence_timeouts() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_and_handle_evidence_timeouts() IS 'Detects evidence timeouts (due_date passed without evidence submission) and updates judgement status to evidence_timeout. Should be called periodically by a cron job or scheduler.';
