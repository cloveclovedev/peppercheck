create type "public"."point_source_type" as enum ('regular', 'trial');

create type "public"."referee_obligation_status" as enum ('pending', 'fulfilled', 'cancelled');

create type "public"."trial_point_reason" as enum ('initial_grant', 'matching_lock', 'matching_unlock', 'matching_settled', 'matching_refund', 'subscription_deactivation');


  create table "public"."referee_obligations" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "status" public.referee_obligation_status not null default 'pending'::public.referee_obligation_status,
    "source_request_id" uuid not null,
    "fulfill_request_id" uuid,
    "created_at" timestamp with time zone not null default now(),
    "fulfilled_at" timestamp with time zone
      );


alter table "public"."referee_obligations" enable row level security;


  create table "public"."trial_point_config" (
    "id" boolean not null default true,
    "initial_grant_amount" integer not null default 3,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."trial_point_config" enable row level security;


  create table "public"."trial_point_ledger" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "amount" integer not null,
    "reason" public.trial_point_reason not null,
    "description" text,
    "related_id" uuid,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."trial_point_ledger" enable row level security;


  create table "public"."trial_point_wallets" (
    "user_id" uuid not null,
    "balance" integer not null default 0,
    "locked" integer not null default 0,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."trial_point_wallets" enable row level security;

alter table "public"."task_referee_requests" add column "is_obligation" boolean not null default false;

alter table "public"."task_referee_requests" add column "point_source" public.point_source_type not null default 'regular'::public.point_source_type;

CREATE INDEX idx_referee_obligations_user_id_status ON public.referee_obligations USING btree (user_id, status);

CREATE INDEX idx_trial_point_ledger_created_at ON public.trial_point_ledger USING btree (created_at);

CREATE INDEX idx_trial_point_ledger_user_id ON public.trial_point_ledger USING btree (user_id);

CREATE UNIQUE INDEX referee_obligations_pkey ON public.referee_obligations USING btree (id);

CREATE UNIQUE INDEX trial_point_config_pkey ON public.trial_point_config USING btree (id);

CREATE UNIQUE INDEX trial_point_ledger_pkey ON public.trial_point_ledger USING btree (id);

CREATE UNIQUE INDEX trial_point_wallets_pkey ON public.trial_point_wallets USING btree (user_id);

alter table "public"."referee_obligations" add constraint "referee_obligations_pkey" PRIMARY KEY using index "referee_obligations_pkey";

alter table "public"."trial_point_config" add constraint "trial_point_config_pkey" PRIMARY KEY using index "trial_point_config_pkey";

alter table "public"."trial_point_ledger" add constraint "trial_point_ledger_pkey" PRIMARY KEY using index "trial_point_ledger_pkey";

alter table "public"."trial_point_wallets" add constraint "trial_point_wallets_pkey" PRIMARY KEY using index "trial_point_wallets_pkey";

alter table "public"."referee_obligations" add constraint "referee_obligations_fulfill_request_id_fkey" FOREIGN KEY (fulfill_request_id) REFERENCES public.task_referee_requests(id) not valid;

alter table "public"."referee_obligations" validate constraint "referee_obligations_fulfill_request_id_fkey";

alter table "public"."referee_obligations" add constraint "referee_obligations_source_request_id_fkey" FOREIGN KEY (source_request_id) REFERENCES public.task_referee_requests(id) not valid;

alter table "public"."referee_obligations" validate constraint "referee_obligations_source_request_id_fkey";

alter table "public"."referee_obligations" add constraint "referee_obligations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."referee_obligations" validate constraint "referee_obligations_user_id_fkey";

alter table "public"."trial_point_config" add constraint "singleton" CHECK ((id = true)) not valid;

alter table "public"."trial_point_config" validate constraint "singleton";

alter table "public"."trial_point_ledger" add constraint "trial_point_ledger_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."trial_point_ledger" validate constraint "trial_point_ledger_user_id_fkey";

alter table "public"."trial_point_wallets" add constraint "trial_point_wallets_balance_check" CHECK ((balance >= 0)) not valid;

alter table "public"."trial_point_wallets" validate constraint "trial_point_wallets_balance_check";

alter table "public"."trial_point_wallets" add constraint "trial_point_wallets_balance_gte_locked" CHECK ((balance >= locked)) not valid;

alter table "public"."trial_point_wallets" validate constraint "trial_point_wallets_balance_gte_locked";

alter table "public"."trial_point_wallets" add constraint "trial_point_wallets_locked_check" CHECK ((locked >= 0)) not valid;

alter table "public"."trial_point_wallets" validate constraint "trial_point_wallets_locked_check";

alter table "public"."trial_point_wallets" add constraint "trial_point_wallets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."trial_point_wallets" validate constraint "trial_point_wallets_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.consume_trial_points(p_user_id uuid, p_amount integer, p_reason public.trial_point_reason DEFAULT 'matching_settled'::public.trial_point_reason, p_description text DEFAULT NULL::text, p_related_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_balance integer;
    v_locked integer;
    v_i integer;
BEGIN
    SELECT balance, locked INTO v_balance, v_locked
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Trial point wallet not found for user %', p_user_id;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient trial points: required %, available %', p_amount, v_balance;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked trial points: required %, locked %', p_amount, v_locked;
    END IF;

    UPDATE public.trial_point_wallets
    SET balance = balance - p_amount,
        locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description, related_id)
    VALUES (p_user_id, -p_amount, p_reason, p_description, p_related_id);

    -- Create referee obligations (1 per point consumed).
    -- p_amount is typically 1 (one point per matching strategy),
    -- but loop handles the general case per spec: "1 trial point consumed = 1 referee obligation".
    FOR v_i IN 1..p_amount LOOP
        INSERT INTO public.referee_obligations (user_id, source_request_id)
        VALUES (p_user_id, p_related_id);
    END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.deactivate_trial_points(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_is_active boolean;
BEGIN
    SELECT is_active INTO v_is_active
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    -- No wallet = nothing to deactivate (existing user before feature launch)
    IF v_is_active IS NULL THEN
        RETURN;
    END IF;

    -- Already deactivated = idempotent
    IF NOT v_is_active THEN
        RETURN;
    END IF;

    UPDATE public.trial_point_wallets
    SET is_active = false,
        updated_at = now()
    WHERE user_id = p_user_id;

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description)
    VALUES (p_user_id, 0, 'subscription_deactivation'::public.trial_point_reason, 'Trial points deactivated on subscription start');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.lock_trial_points(p_user_id uuid, p_amount integer, p_reason public.trial_point_reason DEFAULT 'matching_lock'::public.trial_point_reason, p_description text DEFAULT NULL::text, p_related_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_balance integer;
    v_locked integer;
    v_is_active boolean;
BEGIN
    SELECT balance, locked, is_active INTO v_balance, v_locked, v_is_active
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Trial point wallet not found for user %', p_user_id;
    END IF;

    IF NOT v_is_active THEN
        RAISE EXCEPTION 'Trial point wallet is deactivated for user %', p_user_id;
    END IF;

    IF (v_balance - v_locked) < p_amount THEN
        RAISE EXCEPTION 'Insufficient available trial points: required %, available %', p_amount, (v_balance - v_locked);
    END IF;

    UPDATE public.trial_point_wallets
    SET locked = locked + p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description, related_id)
    VALUES (p_user_id, -p_amount, p_reason, p_description, p_related_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.route_consume_points(p_request_id uuid, p_user_id uuid, p_cost integer, p_description text, p_related_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_point_source public.point_source_type;
BEGIN
    SELECT point_source INTO v_point_source
    FROM public.task_referee_requests
    WHERE id = p_request_id;

    IF v_point_source IS NULL THEN
        RAISE EXCEPTION 'Task referee request not found: %', p_request_id;
    END IF;

    IF v_point_source = 'trial' THEN
        PERFORM public.consume_trial_points(p_user_id, p_cost, 'matching_settled'::public.trial_point_reason, p_description, p_related_id);
    ELSE
        PERFORM public.consume_points(
            p_user_id, p_cost,
            'matching_settled'::public.point_reason,
            p_description, p_related_id
        );
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.route_referee_reward(p_request_id uuid, p_referee_id uuid, p_cost integer, p_reason public.reward_reason, p_description text, p_related_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_is_obligation boolean;
    v_obligation_id uuid;
BEGIN
    SELECT is_obligation INTO v_is_obligation
    FROM public.task_referee_requests
    WHERE id = p_request_id;

    IF v_is_obligation IS NULL THEN
        RAISE EXCEPTION 'Task referee request not found: %', p_request_id;
    END IF;

    IF v_is_obligation THEN
        -- Fulfill oldest pending obligation (FIFO)
        SELECT id INTO v_obligation_id
        FROM public.referee_obligations
        WHERE user_id = p_referee_id
        AND status = 'pending'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE;

        IF v_obligation_id IS NOT NULL THEN
            UPDATE public.referee_obligations
            SET status = 'fulfilled'::public.referee_obligation_status,
                fulfill_request_id = p_request_id,
                fulfilled_at = now()
            WHERE id = v_obligation_id;
        END IF;
        -- No reward granted for obligation fulfillment
    ELSE
        PERFORM public.grant_reward(p_referee_id, p_cost, p_reason, p_description, p_related_id);
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.route_unlock_points(p_request_id uuid, p_user_id uuid, p_cost integer, p_reason_regular public.point_reason, p_reason_trial public.trial_point_reason, p_description text, p_related_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_point_source public.point_source_type;
BEGIN
    SELECT point_source INTO v_point_source
    FROM public.task_referee_requests
    WHERE id = p_request_id;

    IF v_point_source IS NULL THEN
        RAISE EXCEPTION 'Task referee request not found: %', p_request_id;
    END IF;

    IF v_point_source = 'trial' THEN
        PERFORM public.unlock_trial_points(p_user_id, p_cost, p_reason_trial, p_description, p_related_id);
    ELSE
        PERFORM public.unlock_points(p_user_id, p_cost, p_reason_regular, p_description, p_related_id);
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.unlock_trial_points(p_user_id uuid, p_amount integer, p_reason public.trial_point_reason, p_description text DEFAULT NULL::text, p_related_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_locked integer;
BEGIN
    SELECT locked INTO v_locked
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_locked IS NULL THEN
        RAISE EXCEPTION 'Trial point wallet not found for user %', p_user_id;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked trial points: requested %, locked %', p_amount, v_locked;
    END IF;

    UPDATE public.trial_point_wallets
    SET locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description, related_id)
    VALUES (p_user_id, p_amount, p_reason, p_description, p_related_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_initial_grant integer;
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);

  INSERT INTO public.user_ratings (user_id)
  VALUES (NEW.id);

  INSERT INTO public.point_wallets (user_id)
  VALUES (NEW.id);

  -- Create trial point wallet with initial grant from config
  SELECT initial_grant_amount INTO v_initial_grant
  FROM public.trial_point_config
  WHERE id = true;

  v_initial_grant := COALESCE(v_initial_grant, 0);

  IF v_initial_grant > 0 THEN
    INSERT INTO public.trial_point_wallets (user_id, balance)
    VALUES (NEW.id, v_initial_grant);

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description)
    VALUES (NEW.id, v_initial_grant, 'initial_grant'::public.trial_point_reason, 'Trial points granted on registration');
  END IF;

  RETURN NEW;
END;
$function$
;

grant delete on table "public"."referee_obligations" to "anon";

grant insert on table "public"."referee_obligations" to "anon";

grant references on table "public"."referee_obligations" to "anon";

grant select on table "public"."referee_obligations" to "anon";

grant trigger on table "public"."referee_obligations" to "anon";

grant truncate on table "public"."referee_obligations" to "anon";

grant update on table "public"."referee_obligations" to "anon";

grant delete on table "public"."referee_obligations" to "authenticated";

grant insert on table "public"."referee_obligations" to "authenticated";

grant references on table "public"."referee_obligations" to "authenticated";

grant select on table "public"."referee_obligations" to "authenticated";

grant trigger on table "public"."referee_obligations" to "authenticated";

grant truncate on table "public"."referee_obligations" to "authenticated";

grant update on table "public"."referee_obligations" to "authenticated";

grant delete on table "public"."referee_obligations" to "service_role";

grant insert on table "public"."referee_obligations" to "service_role";

grant references on table "public"."referee_obligations" to "service_role";

grant select on table "public"."referee_obligations" to "service_role";

grant trigger on table "public"."referee_obligations" to "service_role";

grant truncate on table "public"."referee_obligations" to "service_role";

grant update on table "public"."referee_obligations" to "service_role";

grant delete on table "public"."trial_point_config" to "anon";

grant insert on table "public"."trial_point_config" to "anon";

grant references on table "public"."trial_point_config" to "anon";

grant select on table "public"."trial_point_config" to "anon";

grant trigger on table "public"."trial_point_config" to "anon";

grant truncate on table "public"."trial_point_config" to "anon";

grant update on table "public"."trial_point_config" to "anon";

grant delete on table "public"."trial_point_config" to "authenticated";

grant insert on table "public"."trial_point_config" to "authenticated";

grant references on table "public"."trial_point_config" to "authenticated";

grant select on table "public"."trial_point_config" to "authenticated";

grant trigger on table "public"."trial_point_config" to "authenticated";

grant truncate on table "public"."trial_point_config" to "authenticated";

grant update on table "public"."trial_point_config" to "authenticated";

grant delete on table "public"."trial_point_config" to "service_role";

grant insert on table "public"."trial_point_config" to "service_role";

grant references on table "public"."trial_point_config" to "service_role";

grant select on table "public"."trial_point_config" to "service_role";

grant trigger on table "public"."trial_point_config" to "service_role";

grant truncate on table "public"."trial_point_config" to "service_role";

grant update on table "public"."trial_point_config" to "service_role";

grant delete on table "public"."trial_point_ledger" to "anon";

grant insert on table "public"."trial_point_ledger" to "anon";

grant references on table "public"."trial_point_ledger" to "anon";

grant select on table "public"."trial_point_ledger" to "anon";

grant trigger on table "public"."trial_point_ledger" to "anon";

grant truncate on table "public"."trial_point_ledger" to "anon";

grant update on table "public"."trial_point_ledger" to "anon";

grant delete on table "public"."trial_point_ledger" to "authenticated";

grant insert on table "public"."trial_point_ledger" to "authenticated";

grant references on table "public"."trial_point_ledger" to "authenticated";

grant select on table "public"."trial_point_ledger" to "authenticated";

grant trigger on table "public"."trial_point_ledger" to "authenticated";

grant truncate on table "public"."trial_point_ledger" to "authenticated";

grant update on table "public"."trial_point_ledger" to "authenticated";

grant delete on table "public"."trial_point_ledger" to "service_role";

grant insert on table "public"."trial_point_ledger" to "service_role";

grant references on table "public"."trial_point_ledger" to "service_role";

grant select on table "public"."trial_point_ledger" to "service_role";

grant trigger on table "public"."trial_point_ledger" to "service_role";

grant truncate on table "public"."trial_point_ledger" to "service_role";

grant update on table "public"."trial_point_ledger" to "service_role";

grant delete on table "public"."trial_point_wallets" to "anon";

grant insert on table "public"."trial_point_wallets" to "anon";

grant references on table "public"."trial_point_wallets" to "anon";

grant select on table "public"."trial_point_wallets" to "anon";

grant trigger on table "public"."trial_point_wallets" to "anon";

grant truncate on table "public"."trial_point_wallets" to "anon";

grant update on table "public"."trial_point_wallets" to "anon";

grant delete on table "public"."trial_point_wallets" to "authenticated";

grant insert on table "public"."trial_point_wallets" to "authenticated";

grant references on table "public"."trial_point_wallets" to "authenticated";

grant select on table "public"."trial_point_wallets" to "authenticated";

grant trigger on table "public"."trial_point_wallets" to "authenticated";

grant truncate on table "public"."trial_point_wallets" to "authenticated";

grant update on table "public"."trial_point_wallets" to "authenticated";

grant delete on table "public"."trial_point_wallets" to "service_role";

grant insert on table "public"."trial_point_wallets" to "service_role";

grant references on table "public"."trial_point_wallets" to "service_role";

grant select on table "public"."trial_point_wallets" to "service_role";

grant trigger on table "public"."trial_point_wallets" to "service_role";

grant truncate on table "public"."trial_point_wallets" to "service_role";

grant update on table "public"."trial_point_wallets" to "service_role";


  create policy "referee_obligations: select if self"
  on "public"."referee_obligations"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "trial_point_config: select all"
  on "public"."trial_point_config"
  as permissive
  for select
  to public
using (true);



  create policy "trial_point_ledger: select if self"
  on "public"."trial_point_ledger"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "trial_point_wallets: select if self"
  on "public"."trial_point_wallets"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));


CREATE TRIGGER on_trial_point_config_update_set_updated_at BEFORE UPDATE ON public.trial_point_config FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_trial_point_wallets_update_set_updated_at BEFORE UPDATE ON public.trial_point_wallets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


