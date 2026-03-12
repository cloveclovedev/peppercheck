CREATE OR REPLACE FUNCTION public.route_unlock_points(
    p_request_id uuid,
    p_user_id uuid,
    p_cost integer,
    p_reason_regular public.point_reason,
    p_reason_trial public.trial_point_reason,
    p_description text,
    p_related_id uuid
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_point_source public.point_source_type;
BEGIN
    SELECT point_source INTO v_point_source
    FROM public.task_referee_requests
    WHERE id = p_request_id;

    IF v_point_source IS NULL THEN
        RAISE EXCEPTION 'Task referee request not found: %', p_request_id;
    END IF;

    IF v_point_source = 'trial' THEN
        PERFORM public.unlock_trial_points(p_user_id, p_cost, p_reason_trial, p_description, p_related_id);
    ELSE
        PERFORM public.unlock_points(p_user_id, p_cost, p_reason_regular, p_description, p_related_id);
    END IF;
END;
$$;

ALTER FUNCTION public.route_unlock_points(uuid, uuid, integer, public.point_reason, public.trial_point_reason, text, uuid) OWNER TO postgres;
