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
    SELECT trr.id, trr.task_id, trr.matching_strategy, trr.status, trr.matched_referee_id, trr.point_source
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

    -- 2. Delete the associated judgement (only if still awaiting_evidence)
    DELETE FROM public.judgements
    WHERE id = p_request_id
    AND status = 'awaiting_evidence';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cannot cancel: judgement has progressed beyond awaiting_evidence';
    END IF;

    -- 3. Insert new request (triggers process_matching via INSERT trigger)
    INSERT INTO public.task_referee_requests (
        task_id, matching_strategy, status, point_source
    ) VALUES (
        v_request.task_id,
        v_request.matching_strategy,
        'pending'::public.referee_request_status,
        v_request.point_source
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

CREATE OR REPLACE FUNCTION public.confirm_judgement_and_rate_referee(p_judgement_id uuid, p_is_positive boolean, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement RECORD;
    v_rows_affected integer;
    v_cost integer;
BEGIN
    -- Get judgement details with task and referee info
    SELECT
        j.id,
        j.status,
        j.is_confirmed,
        trr.task_id,
        trr.matched_referee_id AS referee_id,
        trr.matching_strategy,
        t.tasker_id
    INTO v_judgement
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    -- Validate caller is the tasker
    IF v_judgement.tasker_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the tasker can confirm a judgement';
    END IF;

    -- Validate judgement status
    IF v_judgement.status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Judgement must be in approved or rejected status to confirm';
    END IF;

    -- Idempotency: if already confirmed, do nothing
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Determine point cost from matching strategy
    v_cost := public.get_point_for_matching_strategy(v_judgement.matching_strategy);

    -- Settle points: consume locked points from tasker
    PERFORM public.route_consume_points(
        p_judgement_id,
        v_judgement.tasker_id,
        v_cost,
        'Review confirmed (judgement ' || p_judgement_id || ')',
        p_judgement_id
    );

    -- Grant reward to referee
    PERFORM public.route_referee_reward(
        p_judgement_id,
        v_judgement.referee_id,
        v_cost,
        'review_completed'::public.reward_reason,
        'Review completed (judgement ' || p_judgement_id || ')',
        p_judgement_id
    );

    -- Insert rating (tasker rates referee)
    INSERT INTO public.rating_histories (
        judgement_id,
        ratee_id,
        rater_id,
        rating_type,
        is_positive,
        comment
    ) VALUES (
        p_judgement_id,
        v_judgement.referee_id,
        (SELECT auth.uid()),
        'referee',
        p_is_positive,
        p_comment
    );

    -- Confirm judgement
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Failed to update judgement confirmation status';
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_task_referee_requests_from_json(p_task_id uuid, p_requests jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.detect_auto_confirms()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_now TIMESTAMP WITH TIME ZONE;
    v_rec RECORD;
    v_cost integer;
    v_processed_count integer := 0;
BEGIN
    v_now := NOW();

    -- Process each eligible judgement individually (need per-row settlement for approved/rejected)
    FOR v_rec IN
        SELECT
            j.id AS judgement_id,
            j.status,
            t.tasker_id,
            trr.matched_referee_id AS referee_id,
            trr.matching_strategy,
            t.title AS task_title,
            trr.task_id
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON trr.id = j.id
        JOIN public.tasks t ON t.id = trr.task_id
        WHERE j.is_confirmed = false
        AND j.status IN ('approved', 'rejected', 'review_timeout', 'evidence_timeout')
        AND v_now > (t.due_date + INTERVAL '3 days')
        FOR UPDATE OF j SKIP LOCKED
    LOOP
        -- Settlement for approved/rejected (not yet settled)
        IF v_rec.status IN ('approved', 'rejected') THEN
            v_cost := public.get_point_for_matching_strategy(v_rec.matching_strategy);

            -- Consume locked points from tasker
            PERFORM public.route_consume_points(
                v_rec.judgement_id,
                v_rec.tasker_id,
                v_cost,
                'Auto-confirmed (judgement ' || v_rec.judgement_id || ')',
                v_rec.judgement_id
            );

            -- Grant reward to referee
            PERFORM public.route_referee_reward(
                v_rec.judgement_id,
                v_rec.referee_id,
                v_cost,
                'review_completed'::public.reward_reason,
                'Auto-confirmed (judgement ' || v_rec.judgement_id || ')',
                v_rec.judgement_id
            );

            -- Auto-positive rating
            INSERT INTO public.rating_histories (
                rater_id,
                ratee_id,
                judgement_id,
                rating_type,
                is_positive,
                comment
            ) VALUES (
                v_rec.tasker_id,
                v_rec.referee_id,
                v_rec.judgement_id,
                'referee',
                true,
                NULL
            ) ON CONFLICT (judgement_id, rating_type) DO NOTHING;
        END IF;

        -- Set auto-confirmed and confirmed flags
        UPDATE public.judgements
        SET is_auto_confirmed = true, is_confirmed = true, updated_at = v_now
        WHERE id = v_rec.judgement_id;

        v_processed_count := v_processed_count + 1;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'auto_confirmed_count', v_processed_count,
        'processed_at', v_now
    );
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
    v_obligation_referees UUID[];
    v_is_obligation_match BOOLEAN := false;
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
                    -- Check for referees with pending obligations among candidates
                    SELECT array_agg(ref_id) INTO v_obligation_referees
                    FROM (
                        SELECT DISTINCT ro.user_id as ref_id
                        FROM public.referee_obligations ro
                        WHERE ro.user_id = ANY(v_least_busy_referees)
                        AND ro.status = 'pending'
                    ) obligated;

                    IF COALESCE(array_length(v_obligation_referees, 1), 0) > 0 THEN
                        v_selected_referee := v_obligation_referees[1 + floor(random() * array_length(v_obligation_referees, 1))::INTEGER];
                        v_is_obligation_match := true;
                    ELSE
                        v_selected_referee := v_least_busy_referees[1 + floor(random() * array_length(v_least_busy_referees, 1))::INTEGER];
                        v_is_obligation_match := false;
                    END IF;

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
            responded_at = NOW(),
            is_obligation = v_is_obligation_match
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
        FOR UPDATE OF trr SKIP LOCKED
    LOOP
        UPDATE public.task_referee_requests
        SET status = 'expired'::public.referee_request_status
        WHERE id = v_request.id;

        SELECT t.tasker_id, t.title INTO v_task
        FROM public.tasks t
        WHERE t.id = v_request.task_id;

        v_cost := public.get_point_for_matching_strategy(v_request.matching_strategy);
        PERFORM public.route_unlock_points(
            v_request.id,
            v_task.tasker_id,
            v_cost,
            'matching_refund'::public.point_reason,
            'matching_unlock'::public.trial_point_reason,
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
        FOR UPDATE OF trr SKIP LOCKED
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

CREATE OR REPLACE FUNCTION public.settle_evidence_timeout()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_matching_strategy public.matching_strategy;
    v_cost integer;
BEGIN
    -- Get task and user details
    SELECT t.tasker_id, trr.matched_referee_id, trr.task_id, t.title, trr.matching_strategy
    INTO v_tasker_id, v_referee_id, v_task_id, v_task_title, v_matching_strategy
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RAISE WARNING 'settle_evidence_timeout: request not found for judgement %', NEW.id;
        RETURN NEW;
    END IF;

    -- Determine point cost
    v_cost := public.get_point_for_matching_strategy(v_matching_strategy);

    -- Settle: consume locked points from tasker
    PERFORM public.route_consume_points(
        NEW.id,
        v_tasker_id,
        v_cost,
        'Evidence timeout (judgement ' || NEW.id || ')',
        NEW.id
    );

    -- Grant reward to referee
    PERFORM public.route_referee_reward(
        NEW.id,
        v_referee_id,
        v_cost,
        'evidence_timeout'::public.reward_reason,
        'Evidence timeout (judgement ' || NEW.id || ')',
        NEW.id
    );

    -- Close referee request directly (same pattern as settle_review_timeout)
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;

    -- Notify tasker: evidence timed out
    PERFORM public.notify_event(
        v_tasker_id,
        'notification_evidence_timeout_tasker',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    -- Notify referee: reward granted
    PERFORM public.notify_event(
        v_referee_id,
        'notification_evidence_timeout_referee',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.settle_review_timeout()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_matching_strategy public.matching_strategy;
    v_cost integer;
BEGIN
    SELECT t.tasker_id, trr.matched_referee_id, trr.task_id, t.title, trr.matching_strategy
    INTO v_tasker_id, v_referee_id, v_task_id, v_task_title, v_matching_strategy
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RAISE WARNING 'settle_review_timeout: request not found for judgement %', NEW.id;
        RETURN NEW;
    END IF;

    v_cost := public.get_point_for_matching_strategy(v_matching_strategy);

    -- Return locked points to tasker (no consumption)
    PERFORM public.route_unlock_points(
        NEW.id,
        v_tasker_id,
        v_cost,
        'matching_unlock'::public.point_reason,
        'matching_unlock'::public.trial_point_reason,
        'Review timeout (judgement ' || NEW.id || ')',
        NEW.id
    );

    -- Auto Bad rating for referee
    INSERT INTO public.rating_histories (
        rater_id,
        ratee_id,
        judgement_id,
        rating_type,
        is_positive,
        comment
    ) VALUES (
        v_tasker_id,
        v_referee_id,
        NEW.id,
        'referee',
        false,
        NULL
    ) ON CONFLICT (judgement_id, rating_type) DO NOTHING;

    -- Close referee_request directly
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;

    -- Notify tasker
    PERFORM public.notify_event(
        v_tasker_id,
        'notification_review_timeout_tasker',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    -- Notify referee
    PERFORM public.notify_event(
        v_referee_id,
        'notification_review_timeout_referee',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.validate_task_open_requirements(p_user_id uuid, p_due_date timestamp with time zone, p_referee_requests jsonb[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_min_hours int;
    v_new_cost int := 0;
    v_wallet_balance int;
    v_wallet_locked int;
    v_req jsonb;
    v_strategy public.matching_strategy;
    v_trial_balance int;
    v_trial_locked int;
    v_trial_active boolean;
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

    -- Check trial wallet FIRST
    SELECT balance, locked, is_active INTO v_trial_balance, v_trial_locked, v_trial_active
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id;

    IF v_trial_active IS NOT NULL AND v_trial_active = true
       AND (v_trial_balance - v_trial_locked) >= v_new_cost THEN
        RETURN;  -- Trial points sufficient
    END IF;

    -- Fallback: check regular wallet
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


