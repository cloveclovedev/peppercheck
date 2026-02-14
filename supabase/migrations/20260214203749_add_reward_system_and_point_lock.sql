create type "public"."reward_reason" as enum ('review_completed', 'evidence_timeout', 'payout', 'manual_adjustment');

alter type "public"."point_reason" rename to "point_reason__old_version_to_be_dropped";

create type "public"."point_reason" as enum ('plan_renewal', 'plan_upgrade', 'matching_request', 'matching_lock', 'matching_unlock', 'matching_settled', 'matching_refund', 'manual_adjustment', 'referral_bonus');


  create table "public"."reward_ledger" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "amount" integer not null,
    "reason" public.reward_reason not null,
    "description" text,
    "related_id" uuid,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."reward_ledger" enable row level security;


  create table "public"."reward_wallets" (
    "user_id" uuid not null,
    "balance" integer not null default 0,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."reward_wallets" enable row level security;

alter table "public"."point_ledger" alter column reason type "public"."point_reason" using reason::text::"public"."point_reason";

alter table "public"."point_wallets" add column "locked" integer not null default 0;

CREATE INDEX idx_reward_ledger_created_at ON public.reward_ledger USING btree (created_at);

CREATE INDEX idx_reward_ledger_user_id ON public.reward_ledger USING btree (user_id);

CREATE UNIQUE INDEX reward_ledger_pkey ON public.reward_ledger USING btree (id);

CREATE UNIQUE INDEX reward_wallets_pkey ON public.reward_wallets USING btree (user_id);

alter table "public"."reward_ledger" add constraint "reward_ledger_pkey" PRIMARY KEY using index "reward_ledger_pkey";

alter table "public"."reward_wallets" add constraint "reward_wallets_pkey" PRIMARY KEY using index "reward_wallets_pkey";

alter table "public"."point_wallets" add constraint "point_wallets_balance_gte_locked" CHECK ((balance >= locked)) not valid;

alter table "public"."point_wallets" validate constraint "point_wallets_balance_gte_locked";

alter table "public"."point_wallets" add constraint "point_wallets_locked_check" CHECK ((locked >= 0)) not valid;

alter table "public"."point_wallets" validate constraint "point_wallets_locked_check";

alter table "public"."reward_ledger" add constraint "reward_ledger_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."reward_ledger" validate constraint "reward_ledger_user_id_fkey";

alter table "public"."reward_wallets" add constraint "reward_wallets_balance_check" CHECK ((balance >= 0)) not valid;

alter table "public"."reward_wallets" validate constraint "reward_wallets_balance_check";

alter table "public"."reward_wallets" add constraint "reward_wallets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."reward_wallets" validate constraint "reward_wallets_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.grant_reward(p_user_id uuid, p_amount integer, p_reason public.reward_reason, p_description text DEFAULT NULL::text, p_related_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    -- Upsert reward wallet (create if not exists)
    INSERT INTO public.reward_wallets (user_id, balance)
    VALUES (p_user_id, p_amount)
    ON CONFLICT (user_id) DO UPDATE
    SET balance = public.reward_wallets.balance + p_amount,
        updated_at = now();

    -- Insert ledger entry
    INSERT INTO public.reward_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.lock_points(p_user_id uuid, p_amount integer, p_reason public.point_reason, p_description text DEFAULT NULL::text, p_related_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_balance integer;
    v_locked integer;
BEGIN
    -- Lock row and get current state
    SELECT balance, locked INTO v_balance, v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    -- Check available (unlocked) balance
    IF (v_balance - v_locked) < p_amount THEN
        RAISE EXCEPTION 'Insufficient available points: required %, available %', p_amount, (v_balance - v_locked);
    END IF;

    -- Increase locked amount (balance unchanged)
    UPDATE public.point_wallets
    SET locked = locked + p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Insert ledger entry
    INSERT INTO public.point_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        -p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.unlock_points(p_user_id uuid, p_amount integer, p_reason public.point_reason, p_description text DEFAULT NULL::text, p_related_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_locked integer;
BEGIN
    -- Lock row and get current locked amount
    SELECT locked INTO v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_locked IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked points: requested %, locked %', p_amount, v_locked;
    END IF;

    -- Decrease locked amount (balance unchanged — points returned to available)
    UPDATE public.point_wallets
    SET locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Insert ledger entry (positive = points returned)
    INSERT INTO public.point_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        p_amount,
        p_reason,
        p_description,
        p_related_id
    );
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
    v_cost integer;
BEGIN
    -- Get judgement details with task and referee info
    SELECT
        j.id,
        j.status,
        j.is_confirmed,
        trr.task_id,
        trr.matched_referee_id AS referee_id,
        trr.matching_strategy,
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

    -- Determine point cost from matching strategy
    v_cost := public.get_point_for_matching_strategy(v_judgement.matching_strategy);

    -- Settle points: consume locked points from tasker
    PERFORM public.consume_points(
        v_judgement.tasker_id,
        v_cost,
        'matching_settled'::public.point_reason,
        'Review confirmed (judgement ' || p_judgement_id || ')',
        p_judgement_id
    );

    -- Grant reward to referee
    PERFORM public.grant_reward(
        v_judgement.referee_id,
        v_cost,
        'review_completed'::public.reward_reason,
        'Review completed (judgement ' || p_judgement_id || ')',
        p_judgement_id
    );

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

CREATE OR REPLACE FUNCTION public.consume_points(p_user_id uuid, p_amount integer, p_reason public.point_reason, p_description text DEFAULT NULL::text, p_related_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_balance integer;
    v_locked integer;
BEGIN
    -- Lock row and get current state
    SELECT balance, locked INTO v_balance, v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient points: required %, available %', p_amount, v_balance;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked points: required %, locked %', p_amount, v_locked;
    END IF;

    -- Settle: deduct from both balance and locked
    UPDATE public.point_wallets
    SET balance = balance - p_amount,
        locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Insert ledger entry
    INSERT INTO public.point_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        -p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_matching_request(p_task_id uuid, p_matching_strategy public.matching_strategy, p_preferred_referee_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_cost integer;
    v_request_id uuid;
BEGIN
    v_user_id := auth.uid();

    -- Determine Cost (Hardcoded v1 logic)
    -- TODO: Move to a configuration table if costs become dynamic
    IF p_matching_strategy = 'standard' THEN
        v_cost := 1;
    ELSIF p_matching_strategy = 'premium' THEN
        v_cost := 2;
    ELSIF p_matching_strategy = 'direct' THEN
        v_cost := 1; 
    ELSE
        RAISE EXCEPTION 'Invalid matching strategy: %', p_matching_strategy;
    END IF;

    -- Lock Points (reserved until Confirm settles them)
    PERFORM public.lock_points(
        v_user_id,
        v_cost,
        'matching_lock'::public.point_reason,
        'Matching Request (' || p_matching_strategy || ')',
        p_task_id
    );

    -- Create Request
    INSERT INTO public.task_referee_requests (
        task_id,
        matching_strategy,
        preferred_referee_id,
        status
    ) VALUES (
        p_task_id,
        p_matching_strategy,
        p_preferred_referee_id,
        'pending'::public.referee_request_status
    ) RETURNING id INTO v_request_id;

    RETURN v_request_id;
END;
$function$
;

-- supabase db diff bug workaround: drop old function signature before dropping renamed type
DROP FUNCTION IF EXISTS public.consume_points(uuid, integer, public.point_reason__old_version_to_be_dropped, text, uuid);
drop type "public"."point_reason__old_version_to_be_dropped";

grant delete on table "public"."reward_ledger" to "anon";

grant insert on table "public"."reward_ledger" to "anon";

grant references on table "public"."reward_ledger" to "anon";

grant select on table "public"."reward_ledger" to "anon";

grant trigger on table "public"."reward_ledger" to "anon";

grant truncate on table "public"."reward_ledger" to "anon";

grant update on table "public"."reward_ledger" to "anon";

grant delete on table "public"."reward_ledger" to "authenticated";

grant insert on table "public"."reward_ledger" to "authenticated";

grant references on table "public"."reward_ledger" to "authenticated";

grant select on table "public"."reward_ledger" to "authenticated";

grant trigger on table "public"."reward_ledger" to "authenticated";

grant truncate on table "public"."reward_ledger" to "authenticated";

grant update on table "public"."reward_ledger" to "authenticated";

grant delete on table "public"."reward_ledger" to "service_role";

grant insert on table "public"."reward_ledger" to "service_role";

grant references on table "public"."reward_ledger" to "service_role";

grant select on table "public"."reward_ledger" to "service_role";

grant trigger on table "public"."reward_ledger" to "service_role";

grant truncate on table "public"."reward_ledger" to "service_role";

grant update on table "public"."reward_ledger" to "service_role";

grant delete on table "public"."reward_wallets" to "anon";

grant insert on table "public"."reward_wallets" to "anon";

grant references on table "public"."reward_wallets" to "anon";

grant select on table "public"."reward_wallets" to "anon";

grant trigger on table "public"."reward_wallets" to "anon";

grant truncate on table "public"."reward_wallets" to "anon";

grant update on table "public"."reward_wallets" to "anon";

grant delete on table "public"."reward_wallets" to "authenticated";

grant insert on table "public"."reward_wallets" to "authenticated";

grant references on table "public"."reward_wallets" to "authenticated";

grant select on table "public"."reward_wallets" to "authenticated";

grant trigger on table "public"."reward_wallets" to "authenticated";

grant truncate on table "public"."reward_wallets" to "authenticated";

grant update on table "public"."reward_wallets" to "authenticated";

grant delete on table "public"."reward_wallets" to "service_role";

grant insert on table "public"."reward_wallets" to "service_role";

grant references on table "public"."reward_wallets" to "service_role";

grant select on table "public"."reward_wallets" to "service_role";

grant trigger on table "public"."reward_wallets" to "service_role";

grant truncate on table "public"."reward_wallets" to "service_role";

grant update on table "public"."reward_wallets" to "service_role";


  create policy "reward_ledger: select if self"
  on "public"."reward_ledger"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "reward_wallets: select if self"
  on "public"."reward_wallets"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));


CREATE TRIGGER on_reward_wallets_update_set_updated_at BEFORE UPDATE ON public.reward_wallets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


