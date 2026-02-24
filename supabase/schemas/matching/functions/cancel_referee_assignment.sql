CREATE OR REPLACE FUNCTION public.cancel_referee_assignment(
    p_request_id uuid
) RETURNS json
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
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
$$;

ALTER FUNCTION public.cancel_referee_assignment(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.cancel_referee_assignment(uuid) IS 'Cancels a referee assignment. Creates a new request triggering automatic re-matching. Only callable before cancel_deadline_hours cutoff.';
