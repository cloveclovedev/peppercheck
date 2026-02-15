drop trigger if exists "on_all_requests_closed_close_task" on "public"."task_referee_requests";

drop function if exists "public"."close_task_if_all_requests_closed"();

drop function if exists "public"."confirm_evidence_timeout_from_referee"(p_judgement_id uuid);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_task_id uuid;
BEGIN
    -- Get the task_id for this judgement
    SELECT trr.task_id INTO v_task_id
    FROM public.task_referee_requests trr
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Concurrency protection: lock the task row
    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    -- Check if all judgements for this task are confirmed
    IF NOT EXISTS (
        SELECT 1 FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        WHERE trr.task_id = v_task_id AND j.is_confirmed = false
    ) THEN
        UPDATE public.tasks
        SET status = 'closed'::public.task_status
        WHERE id = v_task_id;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout(p_judgement_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement RECORD;
BEGIN
    -- Get judgement with task info
    SELECT j.id, j.status, j.is_confirmed, j.is_evidence_timeout_confirmed, t.tasker_id
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
        RAISE EXCEPTION 'Only the tasker can confirm an evidence timeout';
    END IF;

    -- Validate status
    IF v_judgement.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in evidence_timeout status to confirm';
    END IF;

    -- Ensure settlement has completed (is_evidence_timeout_confirmed is set by settle_evidence_timeout trigger)
    IF v_judgement.is_evidence_timeout_confirmed != true THEN
        RAISE EXCEPTION 'Settlement has not completed yet';
    END IF;

    -- Idempotency
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Confirm (triggers task closure check via on_all_judgements_confirmed_close_task)
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
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

    -- Auto-set is_evidence_timeout_confirmed to close the request for referee side
    -- This triggers on_judgement_confirmed_close_request → request closes
    UPDATE public.judgements
    SET is_evidence_timeout_confirmed = true
    WHERE id = NEW.id;

    -- Notify tasker: evidence timed out
    PERFORM public.notify_event(
        v_tasker_id,
        'notification_evidence_timeout',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    -- Notify referee: reward granted
    PERFORM public.notify_event(
        v_referee_id,
        'notification_evidence_timeout_reward',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_and_handle_evidence_timeouts()
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
    
    -- Update judgements that have evidence timeout (due_date passed without evidence)
    -- Only update judgements that are still 'open' and past the due date with no evidence
    UPDATE public.judgements j
    SET 
        status = 'evidence_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    LEFT JOIN public.task_evidences te ON t.id = te.task_id
    WHERE j.id = trr.id
    AND j.status = 'awaiting_evidence' -- Changed from 'open' to 'awaiting_evidence' based on enum
    AND v_now > t.due_date
    AND te.id IS NULL; -- No evidence submitted

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF NEW.is_evidence_timeout_confirmed = true
       AND OLD.is_evidence_timeout_confirmed = false
       AND NEW.status = 'evidence_timeout' THEN
        -- No-op: settlement handled by on_evidence_timeout_settle trigger.
        -- Request closure handled by on_judgement_confirmed_close_request trigger.
        NULL;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE TRIGGER on_all_judgements_confirmed_close_task AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.is_confirmed = true) AND (old.is_confirmed = false))) EXECUTE FUNCTION public.close_task_if_all_judgements_confirmed();

CREATE TRIGGER on_evidence_timeout_settle AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.status = 'evidence_timeout'::public.judgement_status) AND (old.status IS DISTINCT FROM new.status))) EXECUTE FUNCTION public.settle_evidence_timeout();

-- Schedule evidence timeout detection cron (DML, not detected by schema diff)
SELECT cron.schedule(
    'detect-evidence-timeouts',
    '*/5 * * * *',
    $$SELECT public.detect_and_handle_evidence_timeouts()$$
);
