drop function if exists "public"."get_point_for_matching_strategy"(p_strategy text);

drop view if exists "public"."judgements_view";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_point_for_matching_strategy(p_strategy public.matching_strategy)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- MVP: Strict validation. Only 'standard' is currently supported.
    IF p_strategy = 'standard' THEN
        RETURN 1;
    ELSE
        RAISE EXCEPTION 'Invalid matching strategy: %. Only standard is supported currently.', p_strategy;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_task_referee_requests_from_json(p_task_id uuid, p_requests jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_req jsonb;
    v_strategy public.matching_strategy;
    v_pref_referee uuid;
BEGIN
    IF p_requests IS NOT NULL THEN
        FOREACH v_req IN ARRAY p_requests
        LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;
            
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
                'pending'::public.referee_request_status
            );
        END LOOP;
    END IF;
END;
$function$
;

create or replace view "public"."judgements_view" as  SELECT j.id,
    trr.task_id,
    trr.matched_referee_id AS referee_id,
    j.comment,
    j.status,
    j.created_at,
    j.updated_at,
    j.is_confirmed,
    j.reopen_count,
    j.is_evidence_timeout_confirmed,
    ((j.status = 'rejected'::public.judgement_status) AND (j.reopen_count < 1) AND (t.due_date > now()) AND (EXISTS ( SELECT 1
           FROM public.task_evidences te
          WHERE ((te.task_id = trr.task_id) AND (te.updated_at > j.updated_at))))) AS can_reopen
   FROM ((public.judgements j
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
     JOIN public.tasks t ON ((trr.task_id = t.id)));


CREATE OR REPLACE FUNCTION public.validate_task_open_requirements(p_user_id uuid, p_due_date timestamp with time zone, p_referee_requests jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_min_hours int;
    v_locked_points int;
    v_new_cost int := 0;
    v_wallet_balance int;
    v_req jsonb;
    v_strategy public.matching_strategy;
BEGIN
    -- 1. Due Date Validation
    SELECT (value::text)::int INTO v_min_hours
    FROM public.matching_config
    WHERE key = 'min_due_date_interval_hours';

    -- Strict Config Validation
    IF v_min_hours IS NULL THEN
        RAISE EXCEPTION 'Configuration missing for min_due_date_interval_hours in matching_config';
    END IF;

    IF p_due_date <= (now() + (v_min_hours || ' hours')::interval) THEN
        RAISE EXCEPTION 'Due date must be at least % hours from now', v_min_hours;
    END IF;

    -- 2. Point Validation
    -- Calculate New Task Cost
    IF p_referee_requests IS NOT NULL THEN
        FOREACH v_req IN ARRAY p_referee_requests
        LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;
            v_new_cost := v_new_cost + public.get_point_for_matching_strategy(v_strategy);
        END LOOP;
    END IF;

    -- Calculate Locked Points
    v_locked_points := public.calculate_locked_points_by_active_tasks(p_user_id);

    -- Get Wallet Balance
    SELECT balance INTO v_wallet_balance
    FROM public.point_wallets
    WHERE user_id = p_user_id;

    IF v_wallet_balance IS NULL THEN
        RAISE EXCEPTION 'Point wallet not found for user';
    END IF;

    -- Check Availability
    -- (Balance - Locked) >= New Cost
    IF (v_wallet_balance - v_locked_points) < v_new_cost THEN
         RAISE EXCEPTION 'Insufficient points. Balance: %, Locked: %, Required: %', v_wallet_balance, v_locked_points, v_new_cost;
    END IF;

END;
$function$
;


