create type "public"."rating_type" as enum ('tasker', 'referee');

drop trigger if exists "on_judgements_confirmed_close_task" on "public"."judgements";

drop trigger if exists "on_judgements_evidence_timeout_close_referee_request" on "public"."judgements";

drop trigger if exists "on_rating_histories_insert_set_rater_id" on "public"."rating_histories";

drop policy "Rating Histories: select if task participant" on "public"."rating_histories";

alter table "public"."rating_histories" drop constraint "rating_histories_rating_check";

alter table "public"."rating_histories" drop constraint "rating_histories_rating_type_check";

alter table "public"."rating_histories" drop constraint "rating_histories_task_id_fkey";

alter table "public"."rating_histories" drop constraint "rating_histories_user_id_fkey";

alter table "public"."rating_histories" drop constraint "unique_rating_per_judgement";

drop function if exists "public"."close_task_if_all_judgements_confirmed"();

drop function if exists "public"."confirm_judgement_and_rate_referee"(p_task_id uuid, p_judgement_id uuid, p_ratee_id uuid, p_rating integer, p_comment text);

drop function if exists "public"."handle_evidence_timeout_confirmation"();

drop function if exists "public"."handle_judgement_confirmation"();

drop function if exists "public"."set_rater_id"();

drop index if exists "public"."idx_rating_histories_task_id";

drop index if exists "public"."idx_rating_histories_user_id";

drop index if exists "public"."idx_rating_histories_user_type";

drop index if exists "public"."unique_rating_per_judgement";

alter table "public"."rating_histories" drop column "rating";

alter table "public"."rating_histories" drop column "task_id";

alter table "public"."rating_histories" add column "is_positive" boolean not null;

alter table "public"."rating_histories" alter column "judgement_id" set not null;

alter table "public"."rating_histories" alter column "rating_type" set data type public.rating_type using "rating_type"::public.rating_type;

alter table "public"."user_ratings" drop column "referee_rating";

alter table "public"."user_ratings" drop column "referee_rating_count";

alter table "public"."user_ratings" drop column "tasker_rating";

alter table "public"."user_ratings" drop column "tasker_rating_count";

alter table "public"."user_ratings" add column "referee_positive_count" integer default 0;

alter table "public"."user_ratings" add column "referee_positive_pct" numeric default 0;

alter table "public"."user_ratings" add column "referee_total_count" integer default 0;

alter table "public"."user_ratings" add column "tasker_positive_count" integer default 0;

alter table "public"."user_ratings" add column "tasker_positive_pct" numeric default 0;

alter table "public"."user_ratings" add column "tasker_total_count" integer default 0;

CREATE INDEX idx_rating_histories_ratee_id ON public.rating_histories USING btree (ratee_id);

CREATE INDEX idx_rating_histories_ratee_type ON public.rating_histories USING btree (ratee_id, rating_type);

CREATE UNIQUE INDEX unique_rating_per_judgement ON public.rating_histories USING btree (judgement_id, rating_type);

alter table "public"."rating_histories" add constraint "fk_rating_histories_ratee_id" FOREIGN KEY (ratee_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."rating_histories" validate constraint "fk_rating_histories_ratee_id";

alter table "public"."rating_histories" add constraint "unique_rating_per_judgement" UNIQUE using index "unique_rating_per_judgement";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.close_referee_request_on_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.close_task_if_all_requests_closed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_task_id uuid;
BEGIN
    v_task_id := NEW.task_id;

    -- Concurrency protection: lock the task row
    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    -- Check if all referee requests for this task are closed
    IF NOT EXISTS (
        SELECT 1 FROM public.task_referee_requests
        WHERE task_id = v_task_id AND status != 'closed'::public.referee_request_status
    ) THEN
        UPDATE public.tasks
        SET status = 'closed'::public.task_status
        WHERE id = v_task_id;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_judgement_and_rate_referee(p_judgement_id uuid, p_is_positive boolean, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement RECORD;
    v_rows_affected integer;
BEGIN
    -- Get judgement details with task and referee info
    SELECT
        j.id,
        j.status,
        j.is_confirmed,
        trr.task_id,
        trr.matched_referee_id AS referee_id,
        t.tasker_id
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
        RAISE EXCEPTION 'Only the tasker can confirm a judgement';
    END IF;

    -- Validate judgement status
    IF v_judgement.status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Judgement must be in approved or rejected status to confirm';
    END IF;

    -- Idempotency: if already confirmed, do nothing
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Insert rating (tasker rates referee)
    INSERT INTO public.rating_histories (
        judgement_id,
        ratee_id,
        rater_id,
        rating_type,
        is_positive,
        comment
    ) VALUES (
        p_judgement_id,
        v_judgement.referee_id,
        (SELECT auth.uid()),
        'referee',
        p_is_positive,
        p_comment
    );

    -- Confirm judgement
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Failed to update judgement confirmation status';
    END IF;
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
    -- Only proceed if is_evidence_timeout_confirmed was changed from false to true
    -- and the judgement status is evidence_timeout
    IF NEW.is_evidence_timeout_confirmed = true
       AND OLD.is_evidence_timeout_confirmed = false
       AND NEW.status = 'evidence_timeout' THEN

        -- Previously triggered billing logic here.
        -- Billing system has been removed.
        -- Request/task closure is handled by on_judgement_confirmed_close_request trigger.
        NULL;

    END IF;

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in handle_evidence_timeout_confirmed: %', SQLERRM;
        RETURN NEW;
END;
$function$
;

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

CREATE OR REPLACE FUNCTION public.auto_score_timeout_referee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement RECORD;
BEGIN
    -- Only process when is_confirmed changes from false to true
    IF TG_OP = 'UPDATE' AND OLD.is_confirmed = false AND NEW.is_confirmed = true THEN

        -- Get the judgement details with task info
        SELECT
            j.id,
            trr.matched_referee_id AS referee_id,
            j.status,
            t.tasker_id
        INTO v_judgement
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        WHERE j.id = NEW.id;

        -- If this is a review_timeout confirmation, automatically score referee negatively
        IF v_judgement.status = 'review_timeout' THEN
            INSERT INTO public.rating_histories (
                rater_id,
                ratee_id,
                judgement_id,
                rating_type,
                is_positive,
                comment
            ) VALUES (
                v_judgement.tasker_id,
                v_judgement.referee_id,
                v_judgement.id,
                'referee',
                false,
                'Automatic negative rating due to referee timeout'
            ) ON CONFLICT (judgement_id, rating_type) DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_user_ratings()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    affected_user_id uuid;
    v_positive integer;
    v_total integer;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.ratee_id;
    ELSE
        affected_user_id := NEW.ratee_id;
    END IF;

    -- Recalculate tasker ratings
    SELECT
        COUNT(*) FILTER (WHERE is_positive = true),
        COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'tasker';

    UPDATE public.user_ratings
    SET
        tasker_positive_count = v_positive,
        tasker_total_count = v_total,
        tasker_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    -- Recalculate referee ratings
    SELECT
        COUNT(*) FILTER (WHERE is_positive = true),
        COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'referee';

    UPDATE public.user_ratings
    SET
        referee_positive_count = v_positive,
        referee_total_count = v_total,
        referee_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$function$
;


  create policy "Rating Histories: select if task participant"
  on "public"."rating_histories"
  as permissive
  for select
  to authenticated
using ((EXISTS ( SELECT 1
   FROM (public.task_referee_requests trr
     JOIN public.tasks t ON ((t.id = trr.task_id)))
  WHERE ((trr.id = rating_histories.judgement_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = ( SELECT auth.uid() AS uid)))))));


CREATE TRIGGER on_judgement_confirmed AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.is_confirmed = true) AND ((old.is_confirmed IS NULL) OR (old.is_confirmed = false)))) EXECUTE FUNCTION public.handle_judgement_confirmed();

CREATE TRIGGER on_judgement_confirmed_close_request AFTER UPDATE ON public.judgements FOR EACH ROW WHEN ((((new.is_confirmed = true) AND (old.is_confirmed = false)) OR ((new.is_evidence_timeout_confirmed = true) AND (old.is_evidence_timeout_confirmed = false)))) EXECUTE FUNCTION public.close_referee_request_on_confirmed();

CREATE TRIGGER on_judgements_evidence_timeout_confirmed AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmed();

CREATE TRIGGER on_all_requests_closed_close_task AFTER UPDATE ON public.task_referee_requests FOR EACH ROW WHEN (((new.status = 'closed'::public.referee_request_status) AND (old.status IS DISTINCT FROM new.status))) EXECUTE FUNCTION public.close_task_if_all_requests_closed();


