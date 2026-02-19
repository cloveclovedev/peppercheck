CREATE OR REPLACE FUNCTION public.settle_review_timeout() RETURNS trigger
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
    PERFORM public.unlock_points(
        v_tasker_id,
        v_cost,
        'matching_unlock'::public.point_reason,
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
$$;

ALTER FUNCTION public.settle_review_timeout() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_review_timeout_settle
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.status = 'review_timeout' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.settle_review_timeout();

COMMENT ON TRIGGER on_review_timeout_settle ON public.judgements IS 'Unlocks tasker points, rates referee negatively, closes request, and sends notifications when review timeout is detected.';
