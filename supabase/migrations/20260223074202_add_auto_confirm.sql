alter table "public"."judgements" add column "is_auto_confirmed" boolean not null default false;

set check_function_bodies = off;

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
            PERFORM public.consume_points(
                v_rec.tasker_id,
                v_cost,
                'matching_settled'::public.point_reason,
                'Auto-confirmed (judgement ' || v_rec.judgement_id || ')',
                v_rec.judgement_id
            );

            -- Grant reward to referee
            PERFORM public.grant_reward(
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

CREATE OR REPLACE FUNCTION public.notify_judgement_confirmed()
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
BEGIN
    -- Get task and user details
    SELECT t.tasker_id, trr.matched_referee_id, trr.task_id, t.title
    INTO v_tasker_id, v_referee_id, v_task_id, v_task_title
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RAISE WARNING 'notify_judgement_confirmed: request not found for judgement %', NEW.id;
        RETURN NEW;
    END IF;

    IF NEW.is_auto_confirmed THEN
        -- Auto-confirm: notify both tasker and referee
        PERFORM public.notify_event(
            v_tasker_id,
            'notification_auto_confirm_tasker',
            ARRAY[v_task_title],
            jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
        );

        PERFORM public.notify_event(
            v_referee_id,
            'notification_auto_confirm_referee',
            ARRAY[v_task_title],
            jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
        );
    -- ELSE: manual confirm notification (future implementation)
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE TRIGGER on_judgement_confirmed_notify AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.is_confirmed = true) AND (old.is_confirmed = false))) EXECUTE FUNCTION public.notify_judgement_confirmed();

-- DML, not detected by schema diff
SELECT cron.schedule(
    'detect-auto-confirms',
    '0 * * * *',
    $$SELECT public.detect_auto_confirms()$$
);
