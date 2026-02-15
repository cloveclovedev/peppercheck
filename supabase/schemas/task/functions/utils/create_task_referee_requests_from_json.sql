CREATE OR REPLACE FUNCTION public.create_task_referee_requests_from_json(
    p_task_id uuid,
    p_requests jsonb[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req jsonb;
    v_strategy public.matching_strategy;
    v_pref_referee uuid;
    v_tasker_id uuid;
BEGIN
    IF p_requests IS NOT NULL THEN
        -- Look up task owner once
        SELECT tasker_id INTO v_tasker_id
        FROM public.tasks
        WHERE id = p_task_id;

        FOREACH v_req IN ARRAY p_requests
        LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;

            IF (v_req->>'preferred_referee_id') IS NOT NULL THEN
                v_pref_referee := (v_req->>'preferred_referee_id')::uuid;
            ELSE
                v_pref_referee := NULL;
            END IF;

            INSERT INTO public.task_referee_requests (
                task_id,
                matching_strategy,
                preferred_referee_id,
                status
            )
            VALUES (
                p_task_id,
                v_strategy,
                v_pref_referee,
                'pending'::public.referee_request_status
            );

            -- Lock points for this matching request
            PERFORM public.lock_points(
                v_tasker_id,
                public.get_point_for_matching_strategy(v_strategy),
                'matching_lock'::public.point_reason,
                'Points locked for matching request',
                p_task_id
            );
        END LOOP;
    END IF;
END;
$$;

ALTER FUNCTION public.create_task_referee_requests_from_json(uuid, jsonb[]) OWNER TO postgres;
