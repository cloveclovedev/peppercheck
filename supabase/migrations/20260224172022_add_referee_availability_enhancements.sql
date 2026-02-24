alter table "public"."task_referee_requests" alter column "status" drop default;

alter type "public"."referee_request_status" rename to "referee_request_status__old_version_to_be_dropped";

create type "public"."referee_request_status" as enum ('pending', 'matched', 'accepted', 'declined', 'expired', 'payment_processing', 'closed', 'cancelled');


  create table "public"."matching_time_config" (
    "id" boolean not null default true,
    "open_deadline_hours" integer not null,
    "cancel_deadline_hours" integer not null,
    "rematch_cutoff_hours" integer not null,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."matching_time_config" enable row level security;


  create table "public"."referee_blocked_dates" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "start_date" date not null,
    "end_date" date not null,
    "reason" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."referee_blocked_dates" enable row level security;

alter table "public"."task_referee_requests" alter column status type "public"."referee_request_status" using status::text::"public"."referee_request_status";

alter table "public"."task_referee_requests" alter column "status" set default 'pending'::public.referee_request_status;

drop type "public"."referee_request_status__old_version_to_be_dropped";

CREATE INDEX idx_referee_blocked_dates_date_range ON public.referee_blocked_dates USING btree (start_date, end_date);

CREATE INDEX idx_referee_blocked_dates_user_id ON public.referee_blocked_dates USING btree (user_id);

CREATE UNIQUE INDEX matching_time_config_pkey ON public.matching_time_config USING btree (id);

CREATE UNIQUE INDEX referee_blocked_dates_pkey ON public.referee_blocked_dates USING btree (id);

alter table "public"."matching_time_config" add constraint "matching_time_config_pkey" PRIMARY KEY using index "matching_time_config_pkey";

alter table "public"."referee_blocked_dates" add constraint "referee_blocked_dates_pkey" PRIMARY KEY using index "referee_blocked_dates_pkey";

alter table "public"."matching_time_config" add constraint "cancel_deadline_positive" CHECK ((cancel_deadline_hours > 0)) not valid;

alter table "public"."matching_time_config" validate constraint "cancel_deadline_positive";

alter table "public"."matching_time_config" add constraint "ordering_invariant" CHECK (((open_deadline_hours > rematch_cutoff_hours) AND (rematch_cutoff_hours > cancel_deadline_hours))) not valid;

alter table "public"."matching_time_config" validate constraint "ordering_invariant";

alter table "public"."matching_time_config" add constraint "singleton" CHECK ((id = true)) not valid;

alter table "public"."matching_time_config" validate constraint "singleton";

alter table "public"."referee_blocked_dates" add constraint "referee_blocked_dates_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."referee_blocked_dates" validate constraint "referee_blocked_dates_user_id_fkey";

alter table "public"."referee_blocked_dates" add constraint "valid_date_range" CHECK ((end_date >= start_date)) not valid;

alter table "public"."referee_blocked_dates" validate constraint "valid_date_range";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.cancel_referee_assignment(p_request_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_request RECORD;
    v_task RECORD;
    v_cfg RECORD;
    v_new_request_id uuid;
    v_new_request_status public.referee_request_status;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get request details
    SELECT trr.id, trr.task_id, trr.matching_strategy, trr.status, trr.matched_referee_id
    INTO v_request
    FROM public.task_referee_requests trr
    WHERE trr.id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    IF v_request.matched_referee_id != v_user_id THEN
        RAISE EXCEPTION 'Only the assigned referee can cancel';
    END IF;

    IF v_request.status != 'accepted' THEN
        RAISE EXCEPTION 'Can only cancel accepted requests, current status: %', v_request.status;
    END IF;

    -- Get task details
    SELECT t.id, t.due_date, t.tasker_id, t.title
    INTO v_task
    FROM public.tasks t
    WHERE t.id = v_request.task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    -- Read cancel deadline from config
    SELECT * INTO STRICT v_cfg
    FROM public.matching_time_config
    WHERE id = true;

    -- Verify cancel deadline not passed
    IF v_task.due_date - (v_cfg.cancel_deadline_hours || ' hours')::interval <= NOW() THEN
        RAISE EXCEPTION 'Cancel deadline has passed (% hours before due date)', v_cfg.cancel_deadline_hours;
    END IF;

    -- 1. Set current request to cancelled
    UPDATE public.task_referee_requests
    SET status = 'cancelled'::public.referee_request_status
    WHERE id = p_request_id;

    -- 2. Delete the associated judgement (awaiting_evidence — no evidence yet)
    DELETE FROM public.judgements
    WHERE id = p_request_id;

    -- 3. Insert new request (triggers process_matching via INSERT trigger)
    INSERT INTO public.task_referee_requests (
        task_id, matching_strategy, status
    ) VALUES (
        v_request.task_id,
        v_request.matching_strategy,
        'pending'::public.referee_request_status
    ) RETURNING id INTO v_new_request_id;

    -- 4. Check if re-matching succeeded (trigger has already run)
    SELECT status INTO v_new_request_status
    FROM public.task_referee_requests
    WHERE id = v_new_request_id;

    -- 5. If re-match failed, notify tasker about pending state
    IF v_new_request_status = 'pending' THEN
        PERFORM public.notify_event(
            v_task.tasker_id,
            'notification_matching_cancelled_pending_tasker',
            ARRAY[v_task.title]::text[],
            jsonb_build_object('route', '/tasks/' || v_request.task_id)
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'cancelled_request_id', p_request_id,
        'new_request_id', v_new_request_id,
        'new_request_status', v_new_request_status
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_referee_blocked_date(p_start_date date, p_end_date date, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_id uuid;
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION 'end_date must be >= start_date';
    END IF;

    INSERT INTO public.referee_blocked_dates (
        user_id, start_date, end_date, reason
    ) VALUES (
        v_user_id, p_start_date, p_end_date, p_reason
    ) RETURNING id INTO v_id;

    RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_referee_blocked_date(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    DELETE FROM public.referee_blocked_dates
    WHERE id = p_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Blocked date not found or not owned by user';
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.process_pending_requests()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_cfg RECORD;
    v_now timestamptz;
    v_request RECORD;
    v_result json;
    v_retry_count int := 0;
    v_retry_success int := 0;
    v_expired_count int := 0;
    v_task RECORD;
    v_cost int;
BEGIN
    v_now := NOW();

    SELECT * INTO STRICT v_cfg
    FROM public.matching_time_config
    WHERE id = true;

    -- 1. Expire pending requests past the rematch cutoff
    FOR v_request IN
        SELECT trr.id, trr.task_id, trr.matching_strategy
        FROM public.task_referee_requests trr
        INNER JOIN public.tasks t ON t.id = trr.task_id
        WHERE trr.status = 'pending'
        AND t.due_date - (v_cfg.rematch_cutoff_hours || ' hours')::interval <= v_now
    LOOP
        UPDATE public.task_referee_requests
        SET status = 'expired'::public.referee_request_status
        WHERE id = v_request.id;

        SELECT t.tasker_id, t.title INTO v_task
        FROM public.tasks t
        WHERE t.id = v_request.task_id;

        v_cost := public.get_point_for_matching_strategy(v_request.matching_strategy);
        PERFORM public.unlock_points(
            v_task.tasker_id,
            v_cost,
            'matching_refund'::public.point_reason,
            'Matching expired — no referee found',
            v_request.task_id
        );

        PERFORM public.notify_event(
            v_task.tasker_id,
            'notification_matching_expired_refunded_tasker',
            ARRAY[v_task.title]::text[],
            jsonb_build_object('route', '/tasks/' || v_request.task_id)
        );

        v_expired_count := v_expired_count + 1;
    END LOOP;

    -- 2. Retry matching for remaining pending requests
    FOR v_request IN
        SELECT trr.id
        FROM public.task_referee_requests trr
        INNER JOIN public.tasks t ON t.id = trr.task_id
        WHERE trr.status = 'pending'
        AND t.due_date - (v_cfg.rematch_cutoff_hours || ' hours')::interval > v_now
    LOOP
        v_retry_count := v_retry_count + 1;

        SELECT public.process_matching(v_request.id) INTO v_result;

        IF (v_result->>'matched')::boolean = true THEN
            v_retry_success := v_retry_success + 1;
        END IF;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'expired_count', v_expired_count,
        'retry_count', v_retry_count,
        'retry_success_count', v_retry_success
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_referee_blocked_date(p_id uuid, p_start_date date, p_end_date date, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION 'end_date must be >= start_date';
    END IF;

    UPDATE public.referee_blocked_dates
    SET start_date = p_start_date,
        end_date = p_end_date,
        reason = p_reason
    WHERE id = p_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Blocked date not found or not owned by user';
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.process_matching(p_request_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_request RECORD;
    v_task RECORD;
    v_matched_referee_id UUID;
    v_due_date TIMESTAMP WITH TIME ZONE;
    v_available_referees UUID[];
    v_min_workload INTEGER;
    v_least_busy_referees UUID[];
    v_selected_referee UUID;
    v_debug_info JSONB;
BEGIN
    v_debug_info := jsonb_build_object();

    -- Get request details
    SELECT
        trr.id,
        trr.task_id,
        trr.matching_strategy,
        trr.preferred_referee_id,
        trr.status
    INTO v_request
    FROM public.task_referee_requests trr
    WHERE trr.id = p_request_id;

    v_debug_info := v_debug_info || jsonb_build_object('request', row_to_json(v_request));

    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Request not found',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    -- Skip if already processed
    IF v_request.status != 'pending' THEN
        RETURN json_build_object(
            'success', true,
            'message', 'Request already processed',
            'status', v_request.status,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    -- Get task details
    SELECT t.id, t.due_date, t.tasker_id, t.status, t.title
    INTO v_task
    FROM public.tasks t
    WHERE t.id = v_request.task_id;

    v_debug_info := v_debug_info || jsonb_build_object('task', row_to_json(v_task));

    IF NOT FOUND OR v_task.status NOT IN ('open') THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Task not found or not available for matching',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    v_due_date := v_task.due_date;

    -- Process matching based on strategy
    CASE v_request.matching_strategy
        WHEN 'standard' THEN
            SELECT ARRAY_AGG(DISTINCT referee_id) INTO v_available_referees
            FROM (
                SELECT
                    rats.user_id as referee_id
                FROM public.referee_available_time_slots rats
                INNER JOIN public.profiles p ON rats.user_id = p.id
                WHERE rats.is_active = true
                AND rats.user_id != v_task.tasker_id
                -- Exclude referees who cancelled this task previously
                AND rats.user_id NOT IN (
                    SELECT trr_c.matched_referee_id
                    FROM public.task_referee_requests trr_c
                    WHERE trr_c.task_id = v_request.task_id
                    AND trr_c.status = 'cancelled'
                    AND trr_c.matched_referee_id IS NOT NULL
                )
                -- Exclude referees blocked on the due date
                AND NOT EXISTS (
                    SELECT 1 FROM public.referee_blocked_dates rbd
                    WHERE rbd.user_id = rats.user_id
                    AND (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date
                        BETWEEN rbd.start_date AND rbd.end_date
                )
                AND EXTRACT(DOW FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) = rats.dow
                AND (EXTRACT(HOUR FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60 +
                     EXTRACT(MINUTE FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) >= rats.start_min
                AND (EXTRACT(HOUR FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60 +
                     EXTRACT(MINUTE FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) <= rats.end_min
            ) available_refs;

            v_debug_info := v_debug_info || jsonb_build_object(
                'available_referees', v_available_referees,
                'available_referees_count', COALESCE(array_length(v_available_referees, 1), 0)
            );

            IF COALESCE(array_length(v_available_referees, 1), 0) = 0 THEN
                v_matched_referee_id := NULL;
            ELSE
                SELECT MIN(workload_count) INTO v_min_workload
                FROM (
                    SELECT
                        COALESCE(COUNT(j.id), 0) as workload_count
                    FROM (SELECT unnest(v_available_referees) as referee_id) refs
                    LEFT JOIN public.task_referee_requests trr ON trr.matched_referee_id = refs.referee_id
                        AND trr.status IN ('accepted', 'matched') 
                    LEFT JOIN public.judgements j ON j.id = trr.id
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'review_timeout')
                    GROUP BY refs.referee_id
                ) workloads;

                v_debug_info := v_debug_info || jsonb_build_object('min_workload', v_min_workload);

                SELECT array_agg(referee_id) INTO v_least_busy_referees
                FROM (
                    SELECT
                        refs.referee_id,
                        COALESCE(COUNT(j.id), 0) as workload_count
                    FROM (SELECT unnest(v_available_referees) as referee_id) refs
                    LEFT JOIN public.task_referee_requests trr ON trr.matched_referee_id = refs.referee_id
                        AND trr.status IN ('accepted', 'matched')
                    LEFT JOIN public.judgements j ON j.id = trr.id
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'review_timeout')
                    GROUP BY refs.referee_id
                    HAVING COALESCE(COUNT(j.id), 0) = v_min_workload
                ) least_busy;

                v_debug_info := v_debug_info || jsonb_build_object(
                    'least_busy_referees', v_least_busy_referees,
                    'least_busy_referees_count', COALESCE(array_length(v_least_busy_referees, 1), 0)
                );

                IF COALESCE(array_length(v_least_busy_referees, 1), 0) > 0 THEN
                    v_selected_referee := v_least_busy_referees[1 + floor(random() * array_length(v_least_busy_referees, 1))::INTEGER];
                    v_matched_referee_id := v_selected_referee;
                    v_debug_info := v_debug_info || jsonb_build_object('selected_referee', v_selected_referee);
                ELSE
                    v_matched_referee_id := NULL;
                END IF;
            END IF;

        WHEN 'premium' THEN
            v_matched_referee_id := NULL;

        WHEN 'direct' THEN
            IF v_request.preferred_referee_id IS NOT NULL THEN
                v_matched_referee_id := v_request.preferred_referee_id;
            ELSE
                v_matched_referee_id := NULL;
            END IF;

        ELSE
            RETURN json_build_object(
                'success', false,
                'error', 'Unknown matching strategy',
                'request_id', p_request_id,
                'strategy', v_request.matching_strategy,
                'debug', v_debug_info
            );
    END CASE;

    IF v_matched_referee_id IS NOT NULL THEN
        UPDATE public.task_referee_requests
        SET
            status = 'accepted'::public.referee_request_status,
            matched_referee_id = v_matched_referee_id,
            responded_at = NOW()
        WHERE id = p_request_id;

        INSERT INTO public.judgements (id, status)
        VALUES (p_request_id, 'awaiting_evidence');

        -- Send notifications concurrently via pg_net (async)
        -- 1. Notify Referee (assigned)
        PERFORM public.notify_event(
            v_matched_referee_id,
            'notification_task_assigned_referee',
            ARRAY[v_task.title]::text[],
            jsonb_build_object('route', '/tasks/' || v_request.task_id)
        );

        -- 2. Notify Tasker (different message for re-matches vs first match)
        IF EXISTS (
            SELECT 1 FROM public.task_referee_requests
            WHERE task_id = v_request.task_id
            AND status = 'cancelled'
        ) THEN
            PERFORM public.notify_event(
                v_task.tasker_id,
                'notification_matching_reassigned_tasker',
                ARRAY[v_task.title]::text[],
                jsonb_build_object('route', '/tasks/' || v_request.task_id)
            );
        ELSE
            PERFORM public.notify_event(
                v_task.tasker_id,
                'notification_request_matched_tasker',
                ARRAY[v_task.title]::text[],
                jsonb_build_object('route', '/tasks/' || v_request.task_id)
            );
        END IF;

        RETURN json_build_object(
            'success', true,
            'matched', true,
            'referee_id', v_matched_referee_id,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    ELSE
        RETURN json_build_object(
            'success', true,
            'matched', false,
            'message', 'No suitable referee found',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
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
    -- 1. Due Date Validation (from matching_time_config singleton)
    SELECT open_deadline_hours INTO STRICT v_min_hours
    FROM public.matching_time_config
    WHERE id = true;

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

grant delete on table "public"."matching_time_config" to "anon";

grant insert on table "public"."matching_time_config" to "anon";

grant references on table "public"."matching_time_config" to "anon";

grant select on table "public"."matching_time_config" to "anon";

grant trigger on table "public"."matching_time_config" to "anon";

grant truncate on table "public"."matching_time_config" to "anon";

grant update on table "public"."matching_time_config" to "anon";

grant delete on table "public"."matching_time_config" to "authenticated";

grant insert on table "public"."matching_time_config" to "authenticated";

grant references on table "public"."matching_time_config" to "authenticated";

grant select on table "public"."matching_time_config" to "authenticated";

grant trigger on table "public"."matching_time_config" to "authenticated";

grant truncate on table "public"."matching_time_config" to "authenticated";

grant update on table "public"."matching_time_config" to "authenticated";

grant delete on table "public"."matching_time_config" to "service_role";

grant insert on table "public"."matching_time_config" to "service_role";

grant references on table "public"."matching_time_config" to "service_role";

grant select on table "public"."matching_time_config" to "service_role";

grant trigger on table "public"."matching_time_config" to "service_role";

grant truncate on table "public"."matching_time_config" to "service_role";

grant update on table "public"."matching_time_config" to "service_role";

grant delete on table "public"."referee_blocked_dates" to "anon";

grant insert on table "public"."referee_blocked_dates" to "anon";

grant references on table "public"."referee_blocked_dates" to "anon";

grant select on table "public"."referee_blocked_dates" to "anon";

grant trigger on table "public"."referee_blocked_dates" to "anon";

grant truncate on table "public"."referee_blocked_dates" to "anon";

grant update on table "public"."referee_blocked_dates" to "anon";

grant delete on table "public"."referee_blocked_dates" to "authenticated";

grant insert on table "public"."referee_blocked_dates" to "authenticated";

grant references on table "public"."referee_blocked_dates" to "authenticated";

grant select on table "public"."referee_blocked_dates" to "authenticated";

grant trigger on table "public"."referee_blocked_dates" to "authenticated";

grant truncate on table "public"."referee_blocked_dates" to "authenticated";

grant update on table "public"."referee_blocked_dates" to "authenticated";

grant delete on table "public"."referee_blocked_dates" to "service_role";

grant insert on table "public"."referee_blocked_dates" to "service_role";

grant references on table "public"."referee_blocked_dates" to "service_role";

grant select on table "public"."referee_blocked_dates" to "service_role";

grant trigger on table "public"."referee_blocked_dates" to "service_role";

grant truncate on table "public"."referee_blocked_dates" to "service_role";

grant update on table "public"."referee_blocked_dates" to "service_role";


  create policy "matching_time_config: read public"
  on "public"."matching_time_config"
  as permissive
  for select
  to public
using (true);



  create policy "referee_blocked_dates: delete for own records"
  on "public"."referee_blocked_dates"
  as permissive
  for delete
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "referee_blocked_dates: insert for own records"
  on "public"."referee_blocked_dates"
  as permissive
  for insert
  to public
with check ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "referee_blocked_dates: select for own records"
  on "public"."referee_blocked_dates"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "referee_blocked_dates: update for own records"
  on "public"."referee_blocked_dates"
  as permissive
  for update
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));


CREATE TRIGGER on_referee_blocked_dates_update_set_updated_at BEFORE UPDATE ON public.referee_blocked_dates FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- DML, not detected by schema diff

-- Seed matching_time_config
INSERT INTO public.matching_time_config
    (open_deadline_hours, cancel_deadline_hours, rematch_cutoff_hours)
VALUES (24, 12, 14);

-- Remove old config row (now in matching_time_config)
DELETE FROM public.matching_config WHERE key = 'min_due_date_interval_hours';

-- Schedule cron job
SELECT cron.schedule(
    'process-pending-requests',
    '0 * * * *',
    $$SELECT public.process_pending_requests()$$
);
