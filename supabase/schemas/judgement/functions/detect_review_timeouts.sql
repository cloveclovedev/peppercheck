CREATE OR REPLACE FUNCTION public.detect_and_handle_review_timeouts() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_timeout_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    -- Update judgements that have review timeout (in_review past due_date + 3 hours)
    UPDATE public.judgements j
    SET
        status = 'review_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    WHERE j.id = trr.id
    AND j.status = 'in_review'
    AND v_now > (t.due_date + INTERVAL '3 hours');

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );
END;
$$;

ALTER FUNCTION public.detect_and_handle_review_timeouts() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_and_handle_review_timeouts() IS 'Detects review timeouts (in_review past due_date + 3h) and updates status to review_timeout. Called by pg_cron every 5 minutes.';
