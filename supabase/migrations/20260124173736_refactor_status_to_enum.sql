create type "public"."evidence_status" as enum ('pending_upload', 'ready');

create type "public"."matching_strategy" as enum ('standard', 'premium', 'direct');

create type "public"."referee_request_status" as enum ('pending', 'matched', 'accepted', 'declined', 'expired', 'payment_processing', 'closed');

create type "public"."task_status" as enum ('draft', 'open', 'closed');

drop trigger if exists "on_task_evidences_update_validate_due_date" on "public"."task_evidences";

alter table "public"."task_evidences" drop constraint "task_evidences_status_check";

alter table "public"."task_referee_requests" drop constraint "task_referee_requests_matching_strategy_check";

alter table "public"."task_referee_requests" drop constraint "task_referee_requests_status_check";

drop function if exists "public"."create_matching_request"(p_task_id uuid, p_matching_strategy text, p_preferred_referee_id uuid);

drop function if exists "public"."create_task"(title text, description text, criteria text, due_date timestamp with time zone, status text, referee_requests jsonb[]);

drop function if exists "public"."update_task"(p_task_id uuid, p_title text, p_description text, p_criteria text, p_due_date timestamp with time zone, p_status text, p_referee_requests jsonb[]);

drop function if exists "public"."validate_task_inputs"(p_status text, p_title text, p_description text, p_criteria text, p_due_date timestamp with time zone, p_referee_requests jsonb[]);

drop view if exists "public"."judgements_view";

drop index if exists "public"."idx_task_evidences_status";

drop index if exists "public"."idx_task_referee_requests_matching_strategy";

drop index if exists "public"."idx_task_referee_requests_status";

drop index if exists "public"."idx_tasks_status";

drop index if exists "public"."idx_tasks_status_tasker_id";

alter table "public"."task_evidences" alter column "status" set default 'pending_upload'::public.evidence_status;

alter table "public"."task_evidences" alter column "status" set data type public.evidence_status using "status"::public.evidence_status;

alter table "public"."task_referee_requests" alter column "matching_strategy" set data type public.matching_strategy using "matching_strategy"::public.matching_strategy;

alter table "public"."task_referee_requests" alter column "status" set default 'pending'::public.referee_request_status;

alter table "public"."task_referee_requests" alter column "status" set data type public.referee_request_status using "status"::public.referee_request_status;

alter table "public"."tasks" alter column "status" set default 'draft'::public.task_status;

alter table "public"."tasks" alter column "status" set data type public.task_status using "status"::public.task_status;

CREATE INDEX idx_task_evidences_status ON public.task_evidences USING btree (status);

CREATE INDEX idx_task_referee_requests_matching_strategy ON public.task_referee_requests USING btree (matching_strategy);

CREATE INDEX idx_task_referee_requests_status ON public.task_referee_requests USING btree (status);

CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);

CREATE INDEX idx_tasks_status_tasker_id ON public.tasks USING btree (status, tasker_id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.create_matching_request(p_task_id uuid, p_matching_strategy public.matching_strategy, p_preferred_referee_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_cost integer;
    v_request_id uuid;
BEGIN
    v_user_id := auth.uid();

    -- Determine Cost (Hardcoded v1 logic)
    -- TODO: Move to a configuration table if costs become dynamic
    IF p_matching_strategy = 'standard' THEN
        v_cost := 1;
    ELSIF p_matching_strategy = 'premium' THEN
        v_cost := 2;
    ELSIF p_matching_strategy = 'direct' THEN
        v_cost := 1; 
    ELSE
        RAISE EXCEPTION 'Invalid matching strategy: %', p_matching_strategy;
    END IF;

    -- Consume Points (Atomic transaction)
    -- Using 'matching_request' reason code
    PERFORM public.consume_points(
        v_user_id,
        v_cost,
        'matching_request'::public.point_reason,
        'Matching Request (' || p_matching_strategy || ')',
        p_task_id
    );

    -- Create Request
    INSERT INTO public.task_referee_requests (
        task_id,
        matching_strategy,
        preferred_referee_id,
        status
    ) VALUES (
        p_task_id,
        p_matching_strategy,
        p_preferred_referee_id,
        'pending'::public.referee_request_status
    ) RETURNING id INTO v_request_id;

    RETURN v_request_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_task(title text, description text DEFAULT NULL::text, criteria text DEFAULT NULL::text, due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, status public.task_status DEFAULT 'draft'::public.task_status, referee_requests jsonb[] DEFAULT NULL::jsonb[])
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

CREATE OR REPLACE FUNCTION public.update_task(p_task_id uuid, p_title text, p_description text DEFAULT NULL::text, p_criteria text DEFAULT NULL::text, p_due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_status public.task_status DEFAULT 'draft'::public.task_status, p_referee_requests jsonb[] DEFAULT NULL::jsonb[])
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_current_status public.task_status;
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

CREATE OR REPLACE FUNCTION public.validate_task_inputs(p_status public.task_status, p_title text, p_description text DEFAULT NULL::text, p_criteria text DEFAULT NULL::text, p_due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_referee_requests jsonb[] DEFAULT NULL::jsonb[])
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
    -- Filter out terminal task states
    AND t.status != 'closed'::public.task_status;

    RETURN v_total_points;
END;
$function$
;

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
    UPDATE public.tasks SET status = 'closed'::public.task_status WHERE id = v_task_id;
  END IF;
  
  RETURN NEW;
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

CREATE OR REPLACE FUNCTION public.submit_evidence(p_task_id uuid, p_description text, p_assets jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_evidence_id UUID;
    v_asset JSONB;
    v_updated_count INTEGER;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    -- 1. Validation
    -- 1.1 Input Check
    IF p_description IS NULL OR trim(p_description) = '' THEN
        RAISE EXCEPTION 'Description is required';
    END IF;

    IF p_assets IS NULL OR jsonb_array_length(p_assets) = 0 THEN
        RAISE EXCEPTION 'At least one evidence asset is required';
    END IF;

    -- 1.2 Authorization & Status Check
    -- Check if:
    --   a) User is tasker (Auth check)
    --   b) Task/Judgement is in valid state:
    --      - Status is 'open' (Awaiting Evidence)
    --      - OR Status is 'rejected' AND reopen_count < 1 AND Now < DueDate
    -- Note: We join with tasks to check tasker_id and due_date
    IF NOT EXISTS (
        SELECT 1
        FROM public.tasks t
        JOIN public.task_referee_requests trr ON trr.task_id = t.id
        JOIN public.judgements j ON j.id = trr.id
        WHERE t.id = p_task_id
          AND t.tasker_id = auth.uid()
          AND (
              j.status IN ('awaiting_evidence', 'in_review')
              OR
              (j.status = 'rejected' AND j.reopen_count < 1 AND t.due_date > v_now)
          )
    ) THEN
        RAISE EXCEPTION 'Not authorized or task not in valid state for evidence submission';
    END IF;

    -- 2. Insert Evidence
    INSERT INTO public.task_evidences (
        task_id,
        description,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_task_id,
        p_description,
        'ready'::public.evidence_status, -- Mark as ready since assets are uploaded
        v_now,
        v_now
    ) RETURNING id INTO v_evidence_id;

    -- 2.1 Insert Evidence Assets
    FOR v_asset IN SELECT * FROM jsonb_array_elements(p_assets)
    LOOP
        INSERT INTO public.task_evidence_assets (
            evidence_id,
            file_url,
            file_size_bytes,
            content_type,
            created_at,
            processing_status,
            public_url
        ) VALUES (
            v_evidence_id,
            v_asset->>'file_url',
            (v_asset->>'file_size_bytes')::BIGINT,
            v_asset->>'content_type',
            v_now,
            'completed',
            v_asset->>'public_url'
        );
    END LOOP;

    -- 3. Update Judgements
    -- Transition 'open' or 'rejected' to 'in_review'
    UPDATE public.judgements j
    SET 
        status = 'in_review',
        updated_at = v_now
    FROM public.task_referee_requests trr
    WHERE 
        j.id = trr.id
        AND trr.task_id = p_task_id
        AND (
            j.status IN ('awaiting_evidence', 'in_review')
            OR 
            (j.status = 'rejected' AND j.reopen_count < 1) 
        );

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'evidence_id', v_evidence_id,
        'updated_judgements_count', v_updated_count
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to submit evidence: %', SQLERRM;
END;
$function$
;


