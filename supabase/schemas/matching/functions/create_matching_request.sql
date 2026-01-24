CREATE OR REPLACE FUNCTION public.create_matching_request(
    p_task_id uuid,
    p_matching_strategy public.matching_strategy,
    p_preferred_referee_id uuid DEFAULT NULL
) RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_user_id uuid;
    v_cost integer;
    v_request_id uuid;
BEGIN
    v_user_id := auth.uid();

    -- Determine Cost (Hardcoded v1 logic)
    -- TODO: Move to a configuration table if costs become dynamic
    IF p_matching_strategy = 'standard' THEN
        v_cost := 1;
    ELSIF p_matching_strategy = 'premium' THEN
        v_cost := 2;
    ELSIF p_matching_strategy = 'direct' THEN
        v_cost := 1; 
    ELSE
        RAISE EXCEPTION 'Invalid matching strategy: %', p_matching_strategy;
    END IF;

    -- Consume Points (Atomic transaction)
    -- Using 'matching_request' reason code
    PERFORM public.consume_points(
        v_user_id,
        v_cost,
        'matching_request'::public.point_reason,
        'Matching Request (' || p_matching_strategy || ')',
        p_task_id
    );

    -- Create Request
    INSERT INTO public.task_referee_requests (
        task_id,
        matching_strategy,
        preferred_referee_id,
        status
    ) VALUES (
        p_task_id,
        p_matching_strategy,
        p_preferred_referee_id,
        'pending'::public.referee_request_status
    ) RETURNING id INTO v_request_id;

    RETURN v_request_id;
END;
$$;

ALTER FUNCTION public.create_matching_request(uuid, public.matching_strategy, uuid) OWNER TO postgres;
