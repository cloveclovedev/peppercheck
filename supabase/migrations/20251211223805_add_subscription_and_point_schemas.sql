create type "public"."point_reason" as enum ('plan_renewal', 'plan_upgrade', 'matching_request', 'matching_refund', 'manual_adjustment', 'referral_bonus');

create type "public"."subscription_provider" as enum ('stripe', 'google', 'apple');

create type "public"."subscription_status" as enum ('active', 'past_due', 'canceled', 'unpaid', 'incomplete', 'incomplete_expired', 'trialing', 'paused');

revoke delete on table "public"."billing_settings" from "anon";

revoke insert on table "public"."billing_settings" from "anon";

revoke references on table "public"."billing_settings" from "anon";

revoke select on table "public"."billing_settings" from "anon";

revoke trigger on table "public"."billing_settings" from "anon";

revoke truncate on table "public"."billing_settings" from "anon";

revoke update on table "public"."billing_settings" from "anon";

revoke delete on table "public"."billing_settings" from "authenticated";

revoke insert on table "public"."billing_settings" from "authenticated";

revoke references on table "public"."billing_settings" from "authenticated";

revoke select on table "public"."billing_settings" from "authenticated";

revoke trigger on table "public"."billing_settings" from "authenticated";

revoke truncate on table "public"."billing_settings" from "authenticated";

revoke update on table "public"."billing_settings" from "authenticated";

drop function if exists "public"."claim_billing_job"(p_job_id uuid);


  create table "public"."point_ledger" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "amount" integer not null,
    "reason" public.point_reason not null,
    "description" text,
    "related_id" uuid,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."point_ledger" enable row level security;


  create table "public"."point_wallets" (
    "user_id" uuid not null,
    "balance" integer not null default 0,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."point_wallets" enable row level security;


  create table "public"."subscription_plan_prices" (
    "id" uuid not null default gen_random_uuid(),
    "plan_id" text not null,
    "currency_code" text not null,
    "amount_minor" integer not null,
    "provider" public.subscription_provider not null default 'stripe'::public.subscription_provider,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."subscription_plan_prices" enable row level security;


  create table "public"."subscription_plans" (
    "id" text not null,
    "name" text not null,
    "monthly_points" integer not null,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."subscription_plans" enable row level security;


  create table "public"."user_subscriptions" (
    "user_id" uuid not null,
    "plan_id" text not null,
    "status" public.subscription_status not null,
    "provider" public.subscription_provider not null,
    "stripe_subscription_id" text,
    "google_purchase_token" text,
    "current_period_start" timestamp with time zone not null,
    "current_period_end" timestamp with time zone not null,
    "cancel_at_period_end" boolean not null default false,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."user_subscriptions" enable row level security;

CREATE INDEX idx_point_ledger_created_at ON public.point_ledger USING btree (created_at);

CREATE INDEX idx_point_ledger_user_id ON public.point_ledger USING btree (user_id);

CREATE INDEX idx_user_subscriptions_provider ON public.user_subscriptions USING btree (provider, status);

CREATE INDEX idx_user_subscriptions_stripe_id ON public.user_subscriptions USING btree (stripe_subscription_id);

CREATE UNIQUE INDEX point_ledger_pkey ON public.point_ledger USING btree (id);

CREATE UNIQUE INDEX point_wallets_pkey ON public.point_wallets USING btree (user_id);

CREATE UNIQUE INDEX subscription_plan_prices_pkey ON public.subscription_plan_prices USING btree (id);

CREATE UNIQUE INDEX subscription_plan_prices_unique_price ON public.subscription_plan_prices USING btree (plan_id, currency_code, provider);

CREATE UNIQUE INDEX subscription_plans_pkey ON public.subscription_plans USING btree (id);

CREATE UNIQUE INDEX user_subscriptions_pkey ON public.user_subscriptions USING btree (user_id);

alter table "public"."point_ledger" add constraint "point_ledger_pkey" PRIMARY KEY using index "point_ledger_pkey";

alter table "public"."point_wallets" add constraint "point_wallets_pkey" PRIMARY KEY using index "point_wallets_pkey";

alter table "public"."subscription_plan_prices" add constraint "subscription_plan_prices_pkey" PRIMARY KEY using index "subscription_plan_prices_pkey";

alter table "public"."subscription_plans" add constraint "subscription_plans_pkey" PRIMARY KEY using index "subscription_plans_pkey";

alter table "public"."user_subscriptions" add constraint "user_subscriptions_pkey" PRIMARY KEY using index "user_subscriptions_pkey";

alter table "public"."point_ledger" add constraint "point_ledger_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."point_ledger" validate constraint "point_ledger_user_id_fkey";

alter table "public"."point_wallets" add constraint "point_wallets_balance_check" CHECK ((balance >= 0)) not valid;

alter table "public"."point_wallets" validate constraint "point_wallets_balance_check";

alter table "public"."point_wallets" add constraint "point_wallets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."point_wallets" validate constraint "point_wallets_user_id_fkey";

alter table "public"."subscription_plan_prices" add constraint "subscription_plan_prices_amount_minor_check" CHECK ((amount_minor >= 0)) not valid;

alter table "public"."subscription_plan_prices" validate constraint "subscription_plan_prices_amount_minor_check";

alter table "public"."subscription_plan_prices" add constraint "subscription_plan_prices_currency_code_fkey" FOREIGN KEY (currency_code) REFERENCES public.currencies(code) ON DELETE RESTRICT not valid;

alter table "public"."subscription_plan_prices" validate constraint "subscription_plan_prices_currency_code_fkey";

alter table "public"."subscription_plan_prices" add constraint "subscription_plan_prices_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id) ON DELETE CASCADE not valid;

alter table "public"."subscription_plan_prices" validate constraint "subscription_plan_prices_plan_id_fkey";

alter table "public"."subscription_plan_prices" add constraint "subscription_plan_prices_unique_price" UNIQUE using index "subscription_plan_prices_unique_price";

alter table "public"."subscription_plans" add constraint "subscription_plans_monthly_points_check" CHECK ((monthly_points >= 0)) not valid;

alter table "public"."subscription_plans" validate constraint "subscription_plans_monthly_points_check";

alter table "public"."user_subscriptions" add constraint "user_subscriptions_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id) not valid;

alter table "public"."user_subscriptions" validate constraint "user_subscriptions_plan_id_fkey";

alter table "public"."user_subscriptions" add constraint "user_subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_subscriptions" validate constraint "user_subscriptions_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.block_task_creation_if_unpaid()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_is_billing_action_required boolean;
BEGIN
  v_is_billing_action_required := public.is_billing_action_required(NEW.tasker_id);

  IF v_is_billing_action_required THEN
    RAISE EXCEPTION 'You have an unpaid task. Please update your payment method and retry the payment.';
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_billing_job(p_job_id uuid, p_force_retry boolean DEFAULT false)
 RETURNS SETOF public.billing_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_max_attempts integer;
BEGIN
  SELECT max_retry_attempts
    INTO v_max_attempts
    FROM public.billing_settings
   WHERE id = 1;

  IF v_max_attempts IS NULL THEN
    RAISE EXCEPTION 'claim_billing_job: billing_settings not found or max_retry_attempts is null';
  END IF;

  RETURN QUERY
    UPDATE public.billing_jobs
       SET status = 'processing',
           attempt_count = attempt_count + 1,
           updated_at = now()
      WHERE id = p_job_id
        AND status IN ('pending', 'failed')
       AND (attempt_count < v_max_attempts OR p_force_retry = true)
    RETURNING *;
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
BEGIN
    -- Check balance (lock row)
    SELECT balance INTO v_balance
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient points: required %, available %', p_amount, v_balance;
    END IF;

    -- Update balance
    UPDATE public.point_wallets
    SET balance = balance - p_amount,
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
        -p_amount, -- Ledger records net change
        p_reason,
        p_description,
        p_related_id
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_matching_request(p_task_id uuid, p_matching_strategy text, p_preferred_referee_id uuid DEFAULT NULL::uuid)
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

    -- Consume Points (Atomic transaction)
    -- Using 'matching_request' reason code
    PERFORM public.consume_points(
        v_user_id,
        v_cost,
        'matching_request'::public.point_reason,
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
        'pending'
    ) RETURNING id INTO v_request_id;

    RETURN v_request_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.force_retry_failed_billing_jobs(p_user_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid;
  v_target_user_id uuid;
  v_url text;
  v_service_role_key text;
  v_headers jsonb;
  v_payload jsonb;
  v_limit integer := 50;
  v_count integer := 0;
  r record;
BEGIN
  v_uid := auth.uid();
  v_target_user_id := COALESCE(p_user_id, v_uid);

  IF current_user <> 'service_role' AND v_target_user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT decrypted_secret
    INTO v_url
    FROM vault.decrypted_secrets
   WHERE name = 'billing_worker_url';

  SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
   WHERE name = 'service_role_key';

  IF v_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE EXCEPTION 'force_retry_failed_billing_jobs: missing secret';
  END IF;

  v_headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || v_service_role_key,
    'apikey', v_service_role_key
  );

  FOR r IN
    SELECT bj.id, bj.attempt_count
      FROM public.billing_jobs bj
      JOIN public.task_referee_requests trr ON trr.id = bj.referee_request_id
      JOIN public.tasks t ON t.id = trr.task_id
     WHERE t.tasker_id = v_target_user_id
       AND bj.status = 'failed'
     ORDER BY bj.updated_at ASC
     LIMIT v_limit
     FOR UPDATE SKIP LOCKED
  LOOP
    v_payload := jsonb_build_object('id', r.id, 'force_retry', true);

    PERFORM net.http_post(
      url => v_url,
      body => v_payload,
      headers => v_headers,
      timeout_milliseconds => 8000
    );

    v_count := v_count + 1;
    RAISE LOG 'force_retry_failed_billing_jobs enqueued job % (attempt_count=%)', r.id, r.attempt_count;
  END LOOP;

  RAISE NOTICE 'force_retry_failed_billing_jobs: enqueued % jobs for user %', v_count, v_target_user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_subscription_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_sub public.user_subscriptions%ROWTYPE;
    v_wallet public.point_wallets%ROWTYPE;
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    
    -- Get Subscription
    SELECT * INTO v_sub
    FROM public.user_subscriptions
    WHERE user_id = v_user_id;
    
    -- Get Wallet
    SELECT * INTO v_wallet
    FROM public.point_wallets
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object(
        'subscription', CASE WHEN v_sub.user_id IS NOT NULL THEN jsonb_build_object(
            'status', v_sub.status,
            'plan_id', v_sub.plan_id,
            'provider', v_sub.provider,
            'current_period_end', v_sub.current_period_end,
            'cancel_at_period_end', v_sub.cancel_at_period_end
        ) ELSE NULL END,
        'wallet', CASE WHEN v_wallet.user_id IS NOT NULL THEN jsonb_build_object(
            'balance', v_wallet.balance
        ) ELSE jsonb_build_object('balance', 0) END
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_billing_action_required(p_user_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_target_user_id uuid;
  v_max_attempts integer;
  v_is_billing_action_required boolean;
BEGIN
  v_target_user_id := COALESCE(p_user_id, auth.uid());

  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'is_billing_action_required: user_id not provided and auth.uid() is null';
  END IF;

  SELECT max_retry_attempts
    INTO v_max_attempts
    FROM public.billing_settings
   WHERE id = 1;

  IF v_max_attempts IS NULL THEN
    RAISE EXCEPTION 'is_billing_action_required: billing_settings missing';
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM public.billing_jobs bj
      JOIN public.task_referee_requests trr ON trr.id = bj.referee_request_id
      JOIN public.tasks t ON t.id = trr.task_id
     WHERE t.tasker_id = v_target_user_id
       AND bj.status = 'failed'
       AND bj.attempt_count >= v_max_attempts
  ) INTO v_is_billing_action_required;

  RETURN v_is_billing_action_required;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.retry_failed_billing_jobs()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_url text;
  v_service_role_key text;
  v_headers jsonb;
  v_payload jsonb;
  v_max_attempts integer;
  v_limit integer := 50;
  v_count integer := 0;
  r record;
BEGIN
  SELECT decrypted_secret
    INTO v_url
    FROM vault.decrypted_secrets
   WHERE name = 'billing_worker_url';

  SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
   WHERE name = 'service_role_key';

  IF v_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'retry_failed_billing_jobs: missing secret (url:%, service_role_key:%)', v_url IS NULL, v_service_role_key IS NULL;
    RETURN;
  END IF;

  SELECT max_retry_attempts
    INTO v_max_attempts
    FROM public.billing_settings
   WHERE id = 1;

  IF v_max_attempts IS NULL THEN
    RAISE EXCEPTION 'retry_failed_billing_jobs: billing_settings not found or max_retry_attempts is null';
  END IF;

  v_headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || v_service_role_key,
    'apikey', v_service_role_key
  );

  FOR r IN
    SELECT id, attempt_count
      FROM public.billing_jobs
     WHERE status = 'failed'
       AND attempt_count < v_max_attempts
     ORDER BY updated_at ASC
     LIMIT v_limit
     FOR UPDATE SKIP LOCKED
  LOOP
    v_payload := jsonb_build_object('id', r.id, 'force_retry', false);

    PERFORM net.http_post(
      url => v_url,
      body => v_payload,
      headers => v_headers,
      timeout_milliseconds => 8000
    );

    v_count := v_count + 1;
    RAISE LOG 'retry_failed_billing_jobs enqueued job % (attempt_count=%)', r.id, r.attempt_count;
  END LOOP;

  RAISE NOTICE 'retry_failed_billing_jobs: enqueued % jobs', v_count;
END;
$function$
;

grant delete on table "public"."point_ledger" to "anon";

grant insert on table "public"."point_ledger" to "anon";

grant references on table "public"."point_ledger" to "anon";

grant select on table "public"."point_ledger" to "anon";

grant trigger on table "public"."point_ledger" to "anon";

grant truncate on table "public"."point_ledger" to "anon";

grant update on table "public"."point_ledger" to "anon";

grant delete on table "public"."point_ledger" to "authenticated";

grant insert on table "public"."point_ledger" to "authenticated";

grant references on table "public"."point_ledger" to "authenticated";

grant select on table "public"."point_ledger" to "authenticated";

grant trigger on table "public"."point_ledger" to "authenticated";

grant truncate on table "public"."point_ledger" to "authenticated";

grant update on table "public"."point_ledger" to "authenticated";

grant delete on table "public"."point_ledger" to "service_role";

grant insert on table "public"."point_ledger" to "service_role";

grant references on table "public"."point_ledger" to "service_role";

grant select on table "public"."point_ledger" to "service_role";

grant trigger on table "public"."point_ledger" to "service_role";

grant truncate on table "public"."point_ledger" to "service_role";

grant update on table "public"."point_ledger" to "service_role";

grant delete on table "public"."point_wallets" to "anon";

grant insert on table "public"."point_wallets" to "anon";

grant references on table "public"."point_wallets" to "anon";

grant select on table "public"."point_wallets" to "anon";

grant trigger on table "public"."point_wallets" to "anon";

grant truncate on table "public"."point_wallets" to "anon";

grant update on table "public"."point_wallets" to "anon";

grant delete on table "public"."point_wallets" to "authenticated";

grant insert on table "public"."point_wallets" to "authenticated";

grant references on table "public"."point_wallets" to "authenticated";

grant select on table "public"."point_wallets" to "authenticated";

grant trigger on table "public"."point_wallets" to "authenticated";

grant truncate on table "public"."point_wallets" to "authenticated";

grant update on table "public"."point_wallets" to "authenticated";

grant delete on table "public"."point_wallets" to "service_role";

grant insert on table "public"."point_wallets" to "service_role";

grant references on table "public"."point_wallets" to "service_role";

grant select on table "public"."point_wallets" to "service_role";

grant trigger on table "public"."point_wallets" to "service_role";

grant truncate on table "public"."point_wallets" to "service_role";

grant update on table "public"."point_wallets" to "service_role";

grant delete on table "public"."subscription_plan_prices" to "anon";

grant insert on table "public"."subscription_plan_prices" to "anon";

grant references on table "public"."subscription_plan_prices" to "anon";

grant select on table "public"."subscription_plan_prices" to "anon";

grant trigger on table "public"."subscription_plan_prices" to "anon";

grant truncate on table "public"."subscription_plan_prices" to "anon";

grant update on table "public"."subscription_plan_prices" to "anon";

grant delete on table "public"."subscription_plan_prices" to "authenticated";

grant insert on table "public"."subscription_plan_prices" to "authenticated";

grant references on table "public"."subscription_plan_prices" to "authenticated";

grant select on table "public"."subscription_plan_prices" to "authenticated";

grant trigger on table "public"."subscription_plan_prices" to "authenticated";

grant truncate on table "public"."subscription_plan_prices" to "authenticated";

grant update on table "public"."subscription_plan_prices" to "authenticated";

grant delete on table "public"."subscription_plan_prices" to "service_role";

grant insert on table "public"."subscription_plan_prices" to "service_role";

grant references on table "public"."subscription_plan_prices" to "service_role";

grant select on table "public"."subscription_plan_prices" to "service_role";

grant trigger on table "public"."subscription_plan_prices" to "service_role";

grant truncate on table "public"."subscription_plan_prices" to "service_role";

grant update on table "public"."subscription_plan_prices" to "service_role";

grant delete on table "public"."subscription_plans" to "anon";

grant insert on table "public"."subscription_plans" to "anon";

grant references on table "public"."subscription_plans" to "anon";

grant select on table "public"."subscription_plans" to "anon";

grant trigger on table "public"."subscription_plans" to "anon";

grant truncate on table "public"."subscription_plans" to "anon";

grant update on table "public"."subscription_plans" to "anon";

grant delete on table "public"."subscription_plans" to "authenticated";

grant insert on table "public"."subscription_plans" to "authenticated";

grant references on table "public"."subscription_plans" to "authenticated";

grant select on table "public"."subscription_plans" to "authenticated";

grant trigger on table "public"."subscription_plans" to "authenticated";

grant truncate on table "public"."subscription_plans" to "authenticated";

grant update on table "public"."subscription_plans" to "authenticated";

grant delete on table "public"."subscription_plans" to "service_role";

grant insert on table "public"."subscription_plans" to "service_role";

grant references on table "public"."subscription_plans" to "service_role";

grant select on table "public"."subscription_plans" to "service_role";

grant trigger on table "public"."subscription_plans" to "service_role";

grant truncate on table "public"."subscription_plans" to "service_role";

grant update on table "public"."subscription_plans" to "service_role";

grant delete on table "public"."user_subscriptions" to "anon";

grant insert on table "public"."user_subscriptions" to "anon";

grant references on table "public"."user_subscriptions" to "anon";

grant select on table "public"."user_subscriptions" to "anon";

grant trigger on table "public"."user_subscriptions" to "anon";

grant truncate on table "public"."user_subscriptions" to "anon";

grant update on table "public"."user_subscriptions" to "anon";

grant delete on table "public"."user_subscriptions" to "authenticated";

grant insert on table "public"."user_subscriptions" to "authenticated";

grant references on table "public"."user_subscriptions" to "authenticated";

grant select on table "public"."user_subscriptions" to "authenticated";

grant trigger on table "public"."user_subscriptions" to "authenticated";

grant truncate on table "public"."user_subscriptions" to "authenticated";

grant update on table "public"."user_subscriptions" to "authenticated";

grant delete on table "public"."user_subscriptions" to "service_role";

grant insert on table "public"."user_subscriptions" to "service_role";

grant references on table "public"."user_subscriptions" to "service_role";

grant select on table "public"."user_subscriptions" to "service_role";

grant trigger on table "public"."user_subscriptions" to "service_role";

grant truncate on table "public"."user_subscriptions" to "service_role";

grant update on table "public"."user_subscriptions" to "service_role";


  create policy "point_ledger: select if self"
  on "public"."point_ledger"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "point_wallets: select if self"
  on "public"."point_wallets"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "subscription_plan_prices: read public"
  on "public"."subscription_plan_prices"
  as permissive
  for select
  to public
using (true);



  create policy "subscription_plans: read public"
  on "public"."subscription_plans"
  as permissive
  for select
  to public
using (true);



  create policy "user_subscriptions: select if self"
  on "public"."user_subscriptions"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));


CREATE TRIGGER block_task_creation_if_unpaid BEFORE INSERT ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.block_task_creation_if_unpaid();


