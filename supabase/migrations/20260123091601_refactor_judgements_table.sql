create type "public"."judgement_status" as enum ('awaiting_evidence', 'in_review', 'approved', 'rejected', 'review_timeout', 'evidence_timeout');

drop policy "Thread Assets: insert if participant" on "public"."judgement_thread_assets";

drop policy "Thread Assets: select if participant" on "public"."judgement_thread_assets";

drop policy "Threads: insert if participant" on "public"."judgement_threads";

drop policy "Threads: select if participant" on "public"."judgement_threads";

drop policy "Judgements: insert if referee" on "public"."judgements";

drop policy "Judgements: select if tasker or referee" on "public"."judgements";

drop policy "Judgements: update if referee or tasker" on "public"."judgements";

drop policy "Rating Histories: select if task participant" on "public"."rating_histories";

drop policy "Task Evidence Assets: select if tasker or referee" on "public"."task_evidence_assets";

drop policy "Task Evidences: select if tasker or referee" on "public"."task_evidences";

alter table "public"."judgements" drop constraint "judgements_referee_id_fkey";

alter table "public"."judgements" drop constraint "judgements_referee_request_id_fkey";

alter table "public"."judgements" drop constraint "judgements_referee_request_id_key";

alter table "public"."judgements" drop constraint "judgements_task_id_fkey";

drop view if exists "public"."judgements_ext";

drop index if exists "public"."idx_judgements_referee_id";

drop index if exists "public"."idx_judgements_referee_request_id";

drop index if exists "public"."idx_judgements_task_id";

drop index if exists "public"."judgements_referee_request_id_key";

drop index if exists "public"."idx_judgements_evidence_timeout_confirmed";

alter table "public"."judgements" drop column "referee_id";

alter table "public"."judgements" drop column "referee_request_id";

alter table "public"."judgements" drop column "task_id";

alter table "public"."judgements" alter column "id" drop default;

alter table "public"."judgements" alter column "status" set default 'awaiting_evidence'::public.judgement_status;

alter table "public"."judgements" alter column "status" set data type public.judgement_status using "status"::public.judgement_status;

CREATE INDEX idx_judgements_evidence_timeout_confirmed ON public.judgements USING btree (is_evidence_timeout_confirmed) WHERE (status = 'evidence_timeout'::public.judgement_status);

alter table "public"."judgements" add constraint "judgements_id_fkey" FOREIGN KEY (id) REFERENCES public.task_referee_requests(id) ON DELETE CASCADE not valid;

alter table "public"."judgements" validate constraint "judgements_id_fkey";

set check_function_bodies = off;

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


CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_task_id uuid;
BEGIN
  -- Get task_id from trr
  SELECT task_id INTO v_task_id 
  FROM public.task_referee_requests 
  WHERE id = NEW.id;

  -- Concurrency protection: lock the task row to prevent race conditions
  PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;
  
  -- Check if all judgements for this task are confirmed
  -- We need to check all requests that are 'accepted' or have a judgement
  IF NOT EXISTS (
    SELECT 1 FROM public.judgements j
    JOIN public.task_referee_requests trr ON j.id = trr.id
    WHERE trr.task_id = v_task_id AND j.is_confirmed = FALSE
  ) THEN
    UPDATE public.tasks SET status = 'closed' WHERE id = v_task_id;
  END IF;
  
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_active_referee_tasks()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'task', to_jsonb(t), -- Single task object
        'judgement', to_jsonb(j), -- judgement information with can_reopen
        'tasker_profile', to_jsonb(p) -- Full tasker profile
      )
    ),
    '[]'::jsonb
  )
  FROM
    public.task_referee_requests AS trr
  INNER JOIN
    public.tasks AS t ON trr.task_id = t.id
  LEFT JOIN
    public.judgements_view AS j ON trr.id = j.id -- Use view and join by ID
  INNER JOIN
    public.profiles AS p ON t.tasker_id = p.id
  WHERE
    trr.matched_referee_id = auth.uid()
    AND trr.status IN ('matched', 'accepted');
$function$
;

CREATE OR REPLACE FUNCTION public.handle_judgement_confirmation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_request RECORD;
BEGIN
  -- Only execute when is_confirmed changes from FALSE to TRUE
  IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
    
    -- Get request details for billing
    SELECT * INTO v_request
    FROM public.task_referee_requests
    WHERE id = NEW.id;

    -- Trigger billing (function handles non-billable cases by closing)
    PERFORM public.start_billing(v_request.id);
      
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_task_referee(task_uuid uuid, user_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE STRICT SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM public.task_referee_requests
     WHERE task_id = task_uuid
       AND matched_referee_id = user_uuid
       AND status = 'accepted'
  );
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
                    LEFT JOIN public.task_referee_requests trr ON trr.matched_referee_id = refs.referee_id
                    LEFT JOIN public.judgements j ON j.id = trr.id
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'review_timeout')
                    WHERE trr.status IN ('accepted', 'matched') 
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
                    LEFT JOIN public.judgements j ON j.id = trr.id
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'review_timeout')
                    WHERE trr.status IN ('accepted', 'matched')
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

        INSERT INTO public.judgements (id, status)
        VALUES (p_request_id, 'awaiting_evidence');

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

CREATE OR REPLACE FUNCTION public.reopen_judgement(p_judgement_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_task_id uuid;
  v_can_reopen boolean;
BEGIN
  -- Get judgement details and can_reopen status from the view
  SELECT task_id, can_reopen
  INTO v_task_id, v_can_reopen
  FROM public.judgements_view
  WHERE id = p_judgement_id;

  -- Check if judgement exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Judgement not found';
  END IF;

  -- Security check: Only tasker can reopen their judgement
  IF NOT public.is_task_tasker(v_task_id, (SELECT auth.uid())) THEN
    RAISE EXCEPTION 'Only the task owner can request judgement reopening';
  END IF;

  -- Validation: Use the can_reopen logic from judgements_view view
  IF NOT v_can_reopen THEN
    RAISE EXCEPTION 'Judgement cannot be reopened. Check: status must be rejected, reopen count < 1, task not past due date, and evidence updated after judgement.';
  END IF;

  -- All validations passed - reopen the judgement
  UPDATE public.judgements 
  SET 
    status = 'awaiting_evidence',
    reopen_count = reopen_count + 1
  WHERE id = p_judgement_id;

END;
$function$
;


  create policy "Thread Assets: insert if participant"
  on "public"."judgement_thread_assets"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM (((public.judgement_threads jt
     JOIN public.judgements j ON ((jt.judgement_id = j.id)))
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
     JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Thread Assets: select if participant"
  on "public"."judgement_thread_assets"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM (((public.judgement_threads jt
     JOIN public.judgements j ON ((jt.judgement_id = j.id)))
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
     JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Threads: insert if participant"
  on "public"."judgement_threads"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM ((public.judgements j
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
     JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((j.id = judgement_threads.judgement_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Threads: select if participant"
  on "public"."judgement_threads"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM ((public.judgements j
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
     JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((j.id = judgement_threads.judgement_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Judgements: insert if referee"
  on "public"."judgements"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM public.task_referee_requests trr
  WHERE ((trr.id = judgements.id) AND (trr.matched_referee_id = ( SELECT auth.uid() AS uid))))));



  create policy "Judgements: select if tasker or referee"
  on "public"."judgements"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM (public.task_referee_requests trr
     LEFT JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((trr.id = judgements.id) AND ((trr.matched_referee_id = ( SELECT auth.uid() AS uid)) OR (t.tasker_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Judgements: update if referee or tasker"
  on "public"."judgements"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM (public.task_referee_requests trr
     LEFT JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((trr.id = judgements.id) AND ((trr.matched_referee_id = ( SELECT auth.uid() AS uid)) OR (t.tasker_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Rating Histories: select if task participant"
  on "public"."rating_histories"
  as permissive
  for select
  to authenticated
using (((EXISTS ( SELECT 1
   FROM public.tasks t
  WHERE ((t.id = rating_histories.task_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM (public.judgements j
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
  WHERE ((trr.task_id = rating_histories.task_id) AND (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Task Evidence Assets: select if tasker or referee"
  on "public"."task_evidence_assets"
  as permissive
  for select
  to public
using (((EXISTS ( SELECT 1
   FROM (public.task_evidences te
     JOIN public.tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM ((public.task_evidences te
     JOIN public.task_referee_requests trr ON ((trr.task_id = te.task_id)))
     JOIN public.judgements j ON ((j.id = trr.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));



  create policy "Task Evidences: select if tasker or referee"
  on "public"."task_evidences"
  as permissive
  for select
  to public
using (((EXISTS ( SELECT 1
   FROM public.tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM (public.judgements j
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
  WHERE ((trr.task_id = task_evidences.task_id) AND (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));



