set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.confirm_review_timeout(p_judgement_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement RECORD;
BEGIN
    SELECT j.id, j.status, j.is_confirmed, t.tasker_id
    INTO v_judgement
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    IF v_judgement.tasker_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the tasker can confirm a review timeout';
    END IF;

    IF v_judgement.status != 'review_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in review_timeout status to confirm';
    END IF;

    -- Idempotency
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Confirm (triggers on_all_judgements_confirmed_close_task)
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_and_handle_review_timeouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_timeout_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    -- Update judgements that have review timeout (in_review past due_date + 3 hours)
    UPDATE public.judgements j
    SET
        status = 'review_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    WHERE j.id = trr.id
    AND j.status = 'in_review'
    AND v_now > (t.due_date + INTERVAL '3 hours');

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );
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
$function$
;

CREATE TRIGGER on_review_timeout_settle AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.status = 'review_timeout'::public.judgement_status) AND (old.status IS DISTINCT FROM new.status))) EXECUTE FUNCTION public.settle_review_timeout();

-- DML, not detected by schema diff
SELECT cron.schedule(
    'detect-review-timeouts',
    '*/5 * * * *',
    $$SELECT public.detect_and_handle_review_timeouts()$$
);
