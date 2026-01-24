CREATE OR REPLACE FUNCTION public.detect_and_handle_referee_timeouts() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_timeout_count INTEGER := 0;
    v_updated_judgements RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
    v_timeout_threshold TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have timed out (due_date + 3 hours)
    -- Only update judgements that are still 'open' and past the timeout threshold
    UPDATE public.judgements j
    SET 
        status = 'review_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    WHERE j.id = trr.id
    AND j.status = 'in_review' -- Assuming 'open' meant 'in_review' (referee has evidence and needs to judge)
    AND v_now > (t.due_date + INTERVAL '3 hours');

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

ALTER FUNCTION public.detect_and_handle_referee_timeouts() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_and_handle_referee_timeouts() IS 'Detects referee timeouts (due_date + 3 hours) and updates judgement status to judgement_timeout. Should be called periodically by a cron job or scheduler.';
