
  create table "public"."user_fcm_tokens" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "token" text not null,
    "device_type" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "last_active_at" timestamp with time zone default now()
      );


alter table "public"."user_fcm_tokens" enable row level security;

CREATE INDEX idx_user_fcm_tokens_last_active ON public.user_fcm_tokens USING btree (last_active_at);

CREATE INDEX idx_user_fcm_tokens_user_id ON public.user_fcm_tokens USING btree (user_id);

CREATE UNIQUE INDEX user_fcm_tokens_pkey ON public.user_fcm_tokens USING btree (id);

CREATE UNIQUE INDEX user_fcm_tokens_token_key ON public.user_fcm_tokens USING btree (token);

alter table "public"."user_fcm_tokens" add constraint "user_fcm_tokens_pkey" PRIMARY KEY using index "user_fcm_tokens_pkey";

alter table "public"."user_fcm_tokens" add constraint "user_fcm_tokens_token_key" UNIQUE using index "user_fcm_tokens_token_key";

alter table "public"."user_fcm_tokens" add constraint "user_fcm_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_fcm_tokens" validate constraint "user_fcm_tokens_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.notify_event(p_user_id uuid, p_template_key text, p_template_args text[] DEFAULT NULL::text[], p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_url text;
    v_service_role_key text;
    v_headers jsonb;
    v_payload jsonb;
BEGIN
    -- Get secrets
    SELECT decrypted_secret
    INTO v_url
    FROM vault.decrypted_secrets
    WHERE name = 'send_notification_url';

    SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key';

    IF v_url IS NULL OR v_service_role_key IS NULL THEN
        -- Log warning but don't fail transaction
        RAISE WARNING 'notify_event: missing secret (url:%, service_role_key found:%)', v_url, v_service_role_key IS NOT NULL;
        RETURN;
    END IF;

    v_headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key,
        'apikey', v_service_role_key
    );

    v_payload := jsonb_build_object(
        'user_ids', jsonb_build_array(p_user_id),
        'notification', jsonb_build_object(
            'title_loc_key', p_template_key || '_title',
            'title_loc_args', COALESCE(p_template_args, ARRAY[]::text[]),
            'body_loc_key', p_template_key || '_body',
            'body_loc_args', COALESCE(p_template_args, ARRAY[]::text[]),
            'data', p_data
        )
    );

    -- Send via pg_net
    PERFORM net.http_post(
        url => v_url,
        body => v_payload,
        headers => v_headers,
        timeout_milliseconds => 5000
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'notify_event failed: %', SQLERRM;
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

    IF NOT FOUND OR v_task.status NOT IN ('open', 'judging') THEN
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
                    LEFT JOIN public.judgements j ON j.referee_id = refs.referee_id
                        AND j.status IN ('open', 'rejected', 'self_closed')
                    GROUP BY refs.referee_id
                ) workloads;

                v_debug_info := v_debug_info || jsonb_build_object('min_workload', v_min_workload);

                SELECT array_agg(referee_id) INTO v_least_busy_referees
                FROM (
                    SELECT
                        refs.referee_id,
                        COALESCE(COUNT(j.id), 0) as workload_count
                    FROM (SELECT unnest(v_available_referees) as referee_id) refs
                    LEFT JOIN public.judgements j ON j.referee_id = refs.referee_id
                        AND j.status IN ('open', 'rejected', 'self_closed')
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
            status = 'accepted',
            matched_referee_id = v_matched_referee_id,
            responded_at = NOW()
        WHERE id = p_request_id;

        INSERT INTO public.judgements (task_id, referee_id, status)
        VALUES (v_request.task_id, v_matched_referee_id, 'open');

        -- Send notifications concurrently via pg_net (async)
        -- 1. Notify Referee (assigned)
        PERFORM public.notify_event(
            v_matched_referee_id,
            'notification_referee_assigned',
            ARRAY[v_task.title]::text[],
            jsonb_build_object('route', '/tasks/' || v_request.task_id)
        );

        -- 2. Notify Tasker (matched/found)
        PERFORM public.notify_event(
            v_task.tasker_id,
            'notification_request_matched',
            ARRAY[v_task.title]::text[],
            jsonb_build_object('route', '/tasks/' || v_request.task_id)
        );

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

grant delete on table "public"."user_fcm_tokens" to "anon";

grant insert on table "public"."user_fcm_tokens" to "anon";

grant references on table "public"."user_fcm_tokens" to "anon";

grant select on table "public"."user_fcm_tokens" to "anon";

grant trigger on table "public"."user_fcm_tokens" to "anon";

grant truncate on table "public"."user_fcm_tokens" to "anon";

grant update on table "public"."user_fcm_tokens" to "anon";

grant delete on table "public"."user_fcm_tokens" to "authenticated";

grant insert on table "public"."user_fcm_tokens" to "authenticated";

grant references on table "public"."user_fcm_tokens" to "authenticated";

grant select on table "public"."user_fcm_tokens" to "authenticated";

grant trigger on table "public"."user_fcm_tokens" to "authenticated";

grant truncate on table "public"."user_fcm_tokens" to "authenticated";

grant update on table "public"."user_fcm_tokens" to "authenticated";

grant delete on table "public"."user_fcm_tokens" to "service_role";

grant insert on table "public"."user_fcm_tokens" to "service_role";

grant references on table "public"."user_fcm_tokens" to "service_role";

grant select on table "public"."user_fcm_tokens" to "service_role";

grant trigger on table "public"."user_fcm_tokens" to "service_role";

grant truncate on table "public"."user_fcm_tokens" to "service_role";

grant update on table "public"."user_fcm_tokens" to "service_role";


  create policy "Users can delete their own tokens"
  on "public"."user_fcm_tokens"
  as permissive
  for delete
  to public
using ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Users can insert their own tokens"
  on "public"."user_fcm_tokens"
  as permissive
  for insert
  to public
with check ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Users can update their own tokens"
  on "public"."user_fcm_tokens"
  as permissive
  for update
  to public
using ((( SELECT auth.uid() AS uid) = user_id));



  create policy "Users can view their own tokens"
  on "public"."user_fcm_tokens"
  as permissive
  for select
  to public
using ((( SELECT auth.uid() AS uid) = user_id));



