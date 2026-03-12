CREATE OR REPLACE FUNCTION public.create_task_referee_requests_from_json(
    p_task_id uuid,
    p_requests jsonb[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_req jsonb;
    v_strategy public.matching_strategy;
    v_pref_referee uuid;
    v_tasker_id uuid;
    v_point_source public.point_source_type;
    v_trial_balance int;
    v_trial_locked int;
    v_trial_active boolean;
    v_total_cost int := 0;
BEGIN
    IF p_requests IS NOT NULL THEN
        -- Look up task owner once
        SELECT tasker_id INTO v_tasker_id
        FROM public.tasks
        WHERE id = p_task_id;

        -- Calculate total cost first
        FOREACH v_req IN ARRAY p_requests LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;
            v_total_cost := v_total_cost + public.get_point_for_matching_strategy(v_strategy);
        END LOOP;

        -- Determine point source
        SELECT balance, locked, is_active INTO v_trial_balance, v_trial_locked, v_trial_active
        FROM public.trial_point_wallets WHERE user_id = v_tasker_id;

        IF v_trial_active IS NOT NULL AND v_trial_active = true
           AND (v_trial_balance - v_trial_locked) >= v_total_cost THEN
            v_point_source := 'trial'::public.point_source_type;
        ELSE
            v_point_source := 'regular'::public.point_source_type;
        END IF;

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
                status,
                point_source
            )
            VALUES (
                p_task_id,
                v_strategy,
                v_pref_referee,
                'pending'::public.referee_request_status,
                v_point_source
            );

            -- Lock points for this matching request
            IF v_point_source = 'trial'::public.point_source_type THEN
                PERFORM public.lock_trial_points(
                    v_tasker_id,
                    public.get_point_for_matching_strategy(v_strategy),
                    'matching_lock'::public.trial_point_reason,
                    'Points locked for matching request',
                    p_task_id
                );
            ELSE
                PERFORM public.lock_points(
                    v_tasker_id,
                    public.get_point_for_matching_strategy(v_strategy),
                    'matching_lock'::public.point_reason,
                    'Points locked for matching request',
                    p_task_id
                );
            END IF;
        END LOOP;
    END IF;
END;
$$;

ALTER FUNCTION public.create_task_referee_requests_from_json(uuid, jsonb[]) OWNER TO postgres;
