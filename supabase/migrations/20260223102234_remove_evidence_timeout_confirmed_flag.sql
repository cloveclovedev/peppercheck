drop trigger if exists "on_judgements_evidence_timeout_confirmed" on "public"."judgements";

drop trigger if exists "on_judgement_confirmed_close_request" on "public"."judgements";

drop function if exists "public"."handle_evidence_timeout_confirmed"();

drop index if exists "public"."idx_judgements_evidence_timeout_confirmed";

alter table "public"."judgements" drop column "is_evidence_timeout_confirmed";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout(p_judgement_id uuid)
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
        RAISE EXCEPTION 'Only the tasker can confirm an evidence timeout';
    END IF;

    IF v_judgement.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in evidence_timeout status to confirm';
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

CREATE OR REPLACE FUNCTION public.get_active_referee_tasks()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'task', to_jsonb(t),
        'judgement', CASE WHEN j.id IS NOT NULL THEN
          jsonb_build_object(
            'id', j.id,
            'comment', j.comment,
            'status', j.status,
            'created_at', j.created_at,
            'updated_at', j.updated_at,
            'is_confirmed', j.is_confirmed,
            'reopen_count', j.reopen_count,
            'can_reopen', (
              j.status = 'rejected'
              AND j.reopen_count < 1
              AND t.due_date > now()
              AND EXISTS (
                SELECT 1 FROM public.task_evidences te
                WHERE te.task_id = trr.task_id
                  AND te.updated_at > j.updated_at
              )
            )
          )
        ELSE NULL END,
        'tasker_profile', to_jsonb(p)
      )
    ),
    '[]'::jsonb
  )
  FROM
    public.task_referee_requests AS trr
  INNER JOIN
    public.tasks AS t ON trr.task_id = t.id
  LEFT JOIN
    public.judgements AS j ON trr.id = j.id
  INNER JOIN
    public.profiles AS p ON t.tasker_id = p.id
  WHERE
    trr.matched_referee_id = auth.uid()
    AND trr.status IN ('matched', 'accepted');
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

CREATE TRIGGER on_judgement_confirmed_close_request AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.is_confirmed = true) AND (old.is_confirmed = false))) EXECUTE FUNCTION public.close_referee_request_on_confirmed();


