drop function if exists "public"."calculate_locked_points_by_active_tasks"(p_user_id uuid);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.create_task_referee_requests_from_json(p_task_id uuid, p_requests jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.validate_task_open_requirements(p_user_id uuid, p_due_date timestamp with time zone, p_referee_requests jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_min_hours int;
    v_new_cost int := 0;
    v_wallet_balance int;
    v_wallet_locked int;
    v_req jsonb;
    v_strategy public.matching_strategy;
BEGIN
    -- 1. Due Date Validation
    SELECT (value::text)::int INTO v_min_hours
    FROM public.matching_config
    WHERE key = 'min_due_date_interval_hours';

    IF v_min_hours IS NULL THEN
        RAISE EXCEPTION 'Configuration missing for min_due_date_interval_hours in matching_config';
    END IF;

    IF p_due_date <= (now() + (v_min_hours || ' hours')::interval) THEN
        RAISE EXCEPTION 'Due date must be at least % hours from now', v_min_hours;
    END IF;

    -- 2. Point Validation
    IF p_referee_requests IS NOT NULL THEN
        FOREACH v_req IN ARRAY p_referee_requests
        LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;
            v_new_cost := v_new_cost + public.get_point_for_matching_strategy(v_strategy);
        END LOOP;
    END IF;

    SELECT balance, locked INTO v_wallet_balance, v_wallet_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id;

    IF v_wallet_balance IS NULL THEN
        RAISE EXCEPTION 'Point wallet not found for user';
    END IF;

    IF (v_wallet_balance - v_wallet_locked) < v_new_cost THEN
         RAISE EXCEPTION 'Insufficient points. Balance: %, Locked: %, Required: %', v_wallet_balance, v_wallet_locked, v_new_cost;
    END IF;
END;
$function$
;


