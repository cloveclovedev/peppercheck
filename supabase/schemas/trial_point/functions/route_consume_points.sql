CREATE OR REPLACE FUNCTION public.route_consume_points(
    p_request_id uuid,
    p_user_id uuid,
    p_cost integer,
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

    IF v_point_source = 'trial' THEN
        PERFORM public.consume_trial_points(p_user_id, p_cost, 'matching_settled'::public.trial_point_reason, p_description, p_related_id);
    ELSE
        PERFORM public.consume_points(
            p_user_id, p_cost,
            'matching_settled'::public.point_reason,
            p_description, p_related_id
        );
    END IF;
END;
$$;

ALTER FUNCTION public.route_consume_points(uuid, uuid, integer, text, uuid) OWNER TO postgres;
