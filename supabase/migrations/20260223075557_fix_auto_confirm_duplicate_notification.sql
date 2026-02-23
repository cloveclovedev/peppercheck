set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_judgement_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
BEGIN
    -- Only execute when is_confirmed changes from FALSE to TRUE
    IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN

        -- Skip if auto-confirmed (handled by on_judgement_confirmed_notify)
        IF NEW.is_auto_confirmed THEN
            RETURN NEW;
        END IF;

        -- Notify referee only for approved/rejected judgements
        IF NEW.status IN ('approved', 'rejected') THEN
            SELECT trr.matched_referee_id, trr.task_id, t.title
            INTO v_referee_id, v_task_id, v_task_title
            FROM public.task_referee_requests trr
            JOIN public.tasks t ON t.id = trr.task_id
            WHERE trr.id = NEW.id;

            IF FOUND THEN
                PERFORM public.notify_event(
                    v_referee_id,
                    'notification_judgement_confirmed',
                    ARRAY[v_task_title],
                    jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
                );
            END IF;
        END IF;

    END IF;

    RETURN NEW;
END;
$function$
;


