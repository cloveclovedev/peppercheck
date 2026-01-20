set check_function_bodies = off;

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
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'self_closed')
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
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'self_closed')
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
        VALUES (v_request.task_id, v_matched_referee_id, 'awaiting_evidence');

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
        JOIN public.judgements j ON j.task_id = t.id
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
        'ready', -- Mark as ready since assets are uploaded
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
    UPDATE public.judgements
    SET 
        status = 'in_review',
        updated_at = v_now
    WHERE 
        task_id = p_task_id 
        AND (
            status IN ('awaiting_evidence', 'in_review')
            OR 
            (status = 'rejected' AND reopen_count < 1) 
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


