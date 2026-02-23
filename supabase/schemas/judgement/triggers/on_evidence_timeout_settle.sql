-- Function + Trigger: Settle points and reward on evidence timeout
CREATE OR REPLACE FUNCTION public.settle_evidence_timeout() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
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
    PERFORM public.consume_points(
        v_tasker_id,
        v_cost,
        'matching_settled'::public.point_reason,
        'Evidence timeout (judgement ' || NEW.id || ')',
        NEW.id
    );

    -- Grant reward to referee
    PERFORM public.grant_reward(
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
$$;

ALTER FUNCTION public.settle_evidence_timeout() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_evidence_timeout_settle
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.status = 'evidence_timeout' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.settle_evidence_timeout();

COMMENT ON TRIGGER on_evidence_timeout_settle ON public.judgements IS 'Settles points (consume from tasker, reward referee) and auto-closes referee side when evidence timeout is detected.';
