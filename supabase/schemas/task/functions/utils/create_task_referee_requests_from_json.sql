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
    v_strategy text;
    v_pref_referee uuid;
BEGIN
    IF p_requests IS NOT NULL THEN
        FOREACH v_req IN ARRAY p_requests
        LOOP
            v_strategy := v_req->>'matching_strategy';
            
            IF (v_req->>'preferred_referee_id') IS NOT NULL THEN
                v_pref_referee := (v_req->>'preferred_referee_id')::uuid;
            ELSE
                v_pref_referee := NULL;
            END IF;

            -- Validation is assumed to be done by Caller (via validate_task_open_requirements)
            -- which calls get_point_for_matching_strategy.
            -- Using "Dumb Helper" pattern as requested.

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
                'pending'
            );
        END LOOP;
    END IF;
END;
$$;

ALTER FUNCTION public.create_task_referee_requests_from_json(uuid, jsonb[]) OWNER TO postgres;
