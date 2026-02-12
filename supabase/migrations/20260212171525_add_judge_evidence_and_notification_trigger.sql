drop view if exists "public"."judgements_view";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.judge_evidence(p_judgement_id uuid, p_status public.judgement_status, p_comment text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_current_status public.judgement_status;
    v_referee_id uuid;
BEGIN
    -- 1. Input Validation
    IF p_status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Status must be approved or rejected';
    END IF;

    IF p_comment IS NULL OR trim(p_comment) = '' THEN
        RAISE EXCEPTION 'Comment is required';
    END IF;

    -- 2. Authorization & Status Check
    SELECT j.status, trr.matched_referee_id
    INTO v_current_status, v_referee_id
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    IF v_referee_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the assigned referee can judge evidence';
    END IF;

    IF v_current_status != 'in_review' THEN
        RAISE EXCEPTION 'Judgement must be in_review status to approve or reject';
    END IF;

    -- 3. Update Judgement
    UPDATE public.judgements
    SET
        status = p_status,
        comment = trim(p_comment)
    WHERE id = p_judgement_id;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.on_judgements_status_changed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_tasker_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_notification_key text;
BEGIN
    -- Early return if status did not change
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Resolve task info via task_referee_requests
    SELECT t.id, t.tasker_id, t.title
    INTO v_task_id, v_tasker_id, v_task_title
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Determine notification based on new status
    CASE NEW.status
        WHEN 'approved' THEN
            v_notification_key := 'notification_judgement_approved';
        WHEN 'rejected' THEN
            v_notification_key := 'notification_judgement_rejected';
        ELSE
            -- Other status changes: no notification for now (future extension point)
            RETURN NEW;
    END CASE;

    -- Send notification to tasker
    PERFORM public.notify_event(
        v_tasker_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

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


CREATE TRIGGER on_judgements_status_changed AFTER UPDATE ON public.judgements FOR EACH ROW WHEN ((old.status IS DISTINCT FROM new.status)) EXECUTE FUNCTION public.on_judgements_status_changed();


