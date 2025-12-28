
  create table "public"."matching_config" (
    "key" text not null,
    "value" jsonb not null,
    "description" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."matching_config" enable row level security;

CREATE UNIQUE INDEX matching_config_pkey ON public.matching_config USING btree (key);

alter table "public"."matching_config" add constraint "matching_config_pkey" PRIMARY KEY using index "matching_config_pkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.calculate_locked_points_by_active_tasks(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_total_points integer;
BEGIN
    -- Sum points for all active requests that represent a liability (locked points)
    -- Active requests: pending, matched, accepted, payment_processing
    -- Active tasks: Not closed/completed/expired (Drafts usually don't have requests, but if they do, we might count them if request status is pending)
    
    SELECT COALESCE(SUM(public.get_point_for_matching_strategy(req.matching_strategy)), 0)
    INTO v_total_points
    FROM public.task_referee_requests req
    JOIN public.tasks t ON req.task_id = t.id
    WHERE t.tasker_id = p_user_id
    AND req.status IN ('pending', 'matched', 'accepted', 'payment_processing')
    -- Filter out terminal task states just in case
    AND t.status NOT IN ('closed', 'completed', 'expired', 'self_completed');

    RETURN v_total_points;
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_point_for_matching_strategy(p_strategy text)
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

CREATE OR REPLACE FUNCTION public.update_task(p_task_id uuid, p_title text, p_description text DEFAULT NULL::text, p_criteria text DEFAULT NULL::text, p_due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_status text DEFAULT 'draft'::text, p_referee_requests jsonb[] DEFAULT NULL::jsonb[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_current_status text;
    v_tasker_id uuid;
    v_req jsonb;
    v_strategy text;
    v_pref_referee uuid;
BEGIN
    -- 1. Check Existence, Ownership, and Current Status
    SELECT status, tasker_id INTO v_current_status, v_tasker_id
    FROM public.tasks
    WHERE id = p_task_id;

    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    IF v_tasker_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to update this task';
    END IF;

    IF v_current_status != 'draft' THEN
        RAISE EXCEPTION 'Only draft tasks can be updated';
    END IF;

    -- 2. Validate Inputs based on Target Status
    -- 2. Validate Inputs based on Target Status
    IF p_status = 'draft' OR p_status = 'open' THEN
        PERFORM public.validate_task_inputs(p_status, p_title, p_description, p_criteria, p_due_date, p_referee_requests);

        -- Shared Logic Validation (Business Logic: Due Date, Points) for Open tasks
        IF p_status = 'open' THEN
            PERFORM public.validate_task_open_requirements(auth.uid(), p_due_date, p_referee_requests);
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid status transition. Can only update to Draft or Open.';
    END IF;

    -- 3. Update Task
    UPDATE public.tasks
    SET title = p_title,
        description = p_description,
        criteria = p_criteria,
        due_date = p_due_date,
        status = p_status,
        updated_at = now()
    WHERE id = p_task_id;

    -- 4. Handle Referee Requests (Only if transitioning to Open)
    IF p_status = 'open' THEN
        -- Theoretically a Draft task shouldn't have requests, but we clean up just in case
        -- to ensure "Replacement" logic.
        DELETE FROM public.task_referee_requests
        WHERE task_id = p_task_id AND status = 'pending';

        PERFORM public.create_task_referee_requests_from_json(p_task_id, p_referee_requests);
    END IF;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.validate_task_inputs(p_status text, p_title text, p_description text DEFAULT NULL::text, p_criteria text DEFAULT NULL::text, p_due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_referee_requests jsonb[] DEFAULT NULL::jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    IF p_status = 'draft' THEN
        IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for draft tasks';
        END IF;
    ELSIF p_status = 'open' THEN
        IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for open tasks';
        END IF;
        IF p_description IS NULL OR length(trim(p_description)) = 0 THEN
             RAISE EXCEPTION 'Description is required for open tasks';
        END IF;
        IF p_criteria IS NULL OR length(trim(p_criteria)) = 0 THEN
             RAISE EXCEPTION 'Criteria is required for open tasks';
        END IF;
        IF p_due_date IS NULL THEN
             RAISE EXCEPTION 'Due date is required for open tasks';
        END IF;
        IF p_referee_requests IS NULL OR array_length(p_referee_requests, 1) IS NULL THEN
             RAISE EXCEPTION 'At least one referee request is required for open tasks';
        END IF;
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
    v_locked_points int;
    v_new_cost int := 0;
    v_wallet_balance int;
    v_req jsonb;
    v_strategy text;
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
            v_strategy := v_req->>'matching_strategy';
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

CREATE OR REPLACE FUNCTION public.create_task(title text, description text DEFAULT NULL::text, criteria text DEFAULT NULL::text, due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, status text DEFAULT 'draft'::text, referee_requests jsonb[] DEFAULT NULL::jsonb[])
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    new_task_id uuid;
    request_item jsonb;
    request_strategy text;
    request_preferred_referee_id uuid;
BEGIN
    -- Validate inputs based on status
    PERFORM public.validate_task_inputs(status, title, description, criteria, due_date, referee_requests);

    -- Shared Logic Validation (Business Logic: Due Date, Points) for Open tasks
    IF status = 'open' THEN
        PERFORM public.validate_task_open_requirements(auth.uid(), due_date, referee_requests);
    END IF;

    -- Insert into tasks
    INSERT INTO public.tasks (
        title,
        description,
        criteria,
        due_date,
        status,
        tasker_id
    )
    VALUES (
        title,
        description,
        criteria,
        due_date,
        status,
        auth.uid()
    )
    RETURNING id INTO new_task_id;

    -- Handle Referee Requests if provided (Only for Open tasks)
    IF status = 'open' THEN
        PERFORM public.create_task_referee_requests_from_json(new_task_id, referee_requests);
    END IF;

    RETURN new_task_id;
END;
$function$
;

grant delete on table "public"."matching_config" to "anon";

grant insert on table "public"."matching_config" to "anon";

grant references on table "public"."matching_config" to "anon";

grant select on table "public"."matching_config" to "anon";

grant trigger on table "public"."matching_config" to "anon";

grant truncate on table "public"."matching_config" to "anon";

grant update on table "public"."matching_config" to "anon";

grant delete on table "public"."matching_config" to "authenticated";

grant insert on table "public"."matching_config" to "authenticated";

grant references on table "public"."matching_config" to "authenticated";

grant select on table "public"."matching_config" to "authenticated";

grant trigger on table "public"."matching_config" to "authenticated";

grant truncate on table "public"."matching_config" to "authenticated";

grant update on table "public"."matching_config" to "authenticated";

grant delete on table "public"."matching_config" to "service_role";

grant insert on table "public"."matching_config" to "service_role";

grant references on table "public"."matching_config" to "service_role";

grant select on table "public"."matching_config" to "service_role";

grant trigger on table "public"."matching_config" to "service_role";

grant truncate on table "public"."matching_config" to "service_role";

grant update on table "public"."matching_config" to "service_role";


  create policy "matching_config: read public"
  on "public"."matching_config"
  as permissive
  for select
  to public
using (true);



