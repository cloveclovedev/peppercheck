alter table "public"."profiles" drop constraint "profiles_id_fkey";

alter table "public"."rating_histories" drop constraint "fk_rating_histories_rater_id";

alter table "public"."reward_payouts" drop constraint "reward_payouts_user_id_fkey";

alter table "public"."task_referee_requests" drop constraint "task_referee_requests_matched_referee_id_fkey";

alter table "public"."task_referee_requests" drop constraint "task_referee_requests_preferred_referee_id_fkey";

alter table "public"."judgement_threads" alter column "sender_id" drop not null;

alter table "public"."reward_payouts" alter column "user_id" drop not null;

alter table "public"."tasks" alter column "tasker_id" drop not null;

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."rating_histories" add constraint "fk_rating_histories_rater_id" FOREIGN KEY (rater_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."rating_histories" validate constraint "fk_rating_histories_rater_id";

alter table "public"."reward_payouts" add constraint "reward_payouts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."reward_payouts" validate constraint "reward_payouts_user_id_fkey";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_matched_referee_id_fkey" FOREIGN KEY (matched_referee_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_matched_referee_id_fkey";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_preferred_referee_id_fkey" FOREIGN KEY (preferred_referee_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_preferred_referee_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.check_account_deletable()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_reasons text[] := '{}';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check open tasks as tasker
    IF EXISTS (
        SELECT 1 FROM public.tasks
        WHERE tasker_id = v_user_id AND status = 'open'
    ) THEN
        v_reasons := array_append(v_reasons, 'open_tasks');
    END IF;

    -- Check active referee requests
    IF EXISTS (
        SELECT 1 FROM public.task_referee_requests
        WHERE matched_referee_id = v_user_id
          AND status IN ('matched', 'accepted', 'payment_processing')
    ) THEN
        v_reasons := array_append(v_reasons, 'active_referee_requests');
    END IF;

    RETURN jsonb_build_object(
        'deletable', array_length(v_reasons, 1) IS NULL,
        'reasons', to_jsonb(v_reasons)
    );
END;
$function$
;


