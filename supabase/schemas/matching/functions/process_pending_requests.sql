CREATE OR REPLACE FUNCTION public.process_pending_requests() RETURNS json
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
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
$$;

ALTER FUNCTION public.process_pending_requests() OWNER TO postgres;

COMMENT ON FUNCTION public.process_pending_requests() IS 'Hourly cron: expires pending requests past rematch_cutoff_hours (refunds points) and retries matching for remaining pending requests.';
