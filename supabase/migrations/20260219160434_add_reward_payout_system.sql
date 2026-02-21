create type "public"."reward_payout_status" as enum ('pending', 'success', 'failed', 'skipped');


  create table "public"."reward_exchange_rates" (
    "currency" text not null,
    "rate_per_point" integer not null,
    "active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "public"."reward_payouts" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "points_amount" integer not null,
    "currency" text not null,
    "currency_amount" integer not null,
    "rate_per_point" integer not null,
    "stripe_transfer_id" text,
    "status" public.reward_payout_status not null default 'pending'::public.reward_payout_status,
    "error_message" text,
    "batch_date" date not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."reward_payouts" enable row level security;

CREATE UNIQUE INDEX reward_exchange_rates_pkey ON public.reward_exchange_rates USING btree (currency);

CREATE UNIQUE INDEX reward_payouts_pkey ON public.reward_payouts USING btree (id);

alter table "public"."reward_exchange_rates" add constraint "reward_exchange_rates_pkey" PRIMARY KEY using index "reward_exchange_rates_pkey";

alter table "public"."reward_payouts" add constraint "reward_payouts_pkey" PRIMARY KEY using index "reward_payouts_pkey";

alter table "public"."reward_payouts" add constraint "reward_payouts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."reward_payouts" validate constraint "reward_payouts_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.deduct_reward_for_payout(p_user_id uuid, p_amount integer, p_payout_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    -- Deduct from wallet
    UPDATE public.reward_wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND balance >= p_amount;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient reward balance for user %', p_user_id;
    END IF;

    -- Log to ledger (negative amount for payout)
    INSERT INTO public.reward_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        -p_amount,
        'payout'::public.reward_reason,
        'Monthly payout',
        p_payout_id
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.prepare_monthly_payouts(p_currency text DEFAULT 'JPY'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_rate integer;
    v_batch_date date := CURRENT_DATE;
    v_wallet RECORD;
    v_pending_count integer := 0;
    v_skipped_count integer := 0;
    v_connect_account_id text;
    v_payouts_enabled boolean;
BEGIN
    -- Guard: only run on the actual last day of the month
    IF v_batch_date != (date_trunc('month', v_batch_date) + interval '1 month' - interval '1 day')::date THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'Not last day of month');
    END IF;

    -- Get active exchange rate
    SELECT rate_per_point INTO v_rate
    FROM public.reward_exchange_rates
    WHERE currency = p_currency AND active = true;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'No active exchange rate for currency: %', p_currency;
    END IF;

    -- Idempotency: skip if payouts already prepared for this batch_date
    IF EXISTS (SELECT 1 FROM public.reward_payouts WHERE batch_date = v_batch_date LIMIT 1) THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'Payouts already prepared for ' || v_batch_date);
    END IF;

    -- Process each wallet with balance > 0
    FOR v_wallet IN
        SELECT user_id, balance FROM public.reward_wallets WHERE balance > 0
    LOOP
        -- Check Connect account status
        -- profiles.id = auth.users.id = stripe_accounts.profile_id
        SELECT sa.stripe_connect_account_id, sa.payouts_enabled
        INTO v_connect_account_id, v_payouts_enabled
        FROM public.stripe_accounts sa
        WHERE sa.profile_id = v_wallet.user_id;

        IF v_connect_account_id IS NOT NULL AND v_payouts_enabled = true THEN
            -- User is ready for payout
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'pending', v_batch_date
            );
            v_pending_count := v_pending_count + 1;
        ELSE
            -- User not ready — skip and notify
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date, error_message
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'skipped', v_batch_date,
                'Connect account not ready (payouts_enabled=false or no account)'
            );
            v_skipped_count := v_skipped_count + 1;

            -- Send reminder notification
            PERFORM public.notify_event(
                v_wallet.user_id,
                'notification_payout_connect_required',
                NULL,
                jsonb_build_object('batch_date', v_batch_date)
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'pending', v_pending_count,
        'skipped', v_skipped_count,
        'batch_date', v_batch_date,
        'currency', p_currency,
        'rate_per_point', v_rate
    );
END;
$function$
;

grant delete on table "public"."reward_exchange_rates" to "anon";

grant insert on table "public"."reward_exchange_rates" to "anon";

grant references on table "public"."reward_exchange_rates" to "anon";

grant select on table "public"."reward_exchange_rates" to "anon";

grant trigger on table "public"."reward_exchange_rates" to "anon";

grant truncate on table "public"."reward_exchange_rates" to "anon";

grant update on table "public"."reward_exchange_rates" to "anon";

grant delete on table "public"."reward_exchange_rates" to "authenticated";

grant insert on table "public"."reward_exchange_rates" to "authenticated";

grant references on table "public"."reward_exchange_rates" to "authenticated";

grant select on table "public"."reward_exchange_rates" to "authenticated";

grant trigger on table "public"."reward_exchange_rates" to "authenticated";

grant truncate on table "public"."reward_exchange_rates" to "authenticated";

grant update on table "public"."reward_exchange_rates" to "authenticated";

grant delete on table "public"."reward_exchange_rates" to "service_role";

grant insert on table "public"."reward_exchange_rates" to "service_role";

grant references on table "public"."reward_exchange_rates" to "service_role";

grant select on table "public"."reward_exchange_rates" to "service_role";

grant trigger on table "public"."reward_exchange_rates" to "service_role";

grant truncate on table "public"."reward_exchange_rates" to "service_role";

grant update on table "public"."reward_exchange_rates" to "service_role";

grant delete on table "public"."reward_payouts" to "anon";

grant insert on table "public"."reward_payouts" to "anon";

grant references on table "public"."reward_payouts" to "anon";

grant select on table "public"."reward_payouts" to "anon";

grant trigger on table "public"."reward_payouts" to "anon";

grant truncate on table "public"."reward_payouts" to "anon";

grant update on table "public"."reward_payouts" to "anon";

grant delete on table "public"."reward_payouts" to "authenticated";

grant insert on table "public"."reward_payouts" to "authenticated";

grant references on table "public"."reward_payouts" to "authenticated";

grant select on table "public"."reward_payouts" to "authenticated";

grant trigger on table "public"."reward_payouts" to "authenticated";

grant truncate on table "public"."reward_payouts" to "authenticated";

grant update on table "public"."reward_payouts" to "authenticated";

grant delete on table "public"."reward_payouts" to "service_role";

grant insert on table "public"."reward_payouts" to "service_role";

grant references on table "public"."reward_payouts" to "service_role";

grant select on table "public"."reward_payouts" to "service_role";

grant trigger on table "public"."reward_payouts" to "service_role";

grant truncate on table "public"."reward_payouts" to "service_role";

grant update on table "public"."reward_payouts" to "service_role";


  create policy "reward_payouts: select if self"
  on "public"."reward_payouts"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));


CREATE TRIGGER on_reward_payouts_update_set_updated_at BEFORE UPDATE ON public.reward_payouts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- DML, not detected by schema diff

-- Seed initial exchange rate
INSERT INTO public.reward_exchange_rates (currency, rate_per_point)
VALUES ('JPY', 50);

-- Schedule monthly payout preparation (last day of month, 00:00 JST = 15:00 UTC)
SELECT cron.schedule(
    'prepare-monthly-payouts',
    '0 15 28-31 * *',
    $$SELECT public.prepare_monthly_payouts('JPY')$$
);

-- Schedule pending payout execution every 30 minutes
SELECT cron.schedule(
    'execute-pending-payouts',
    '*/30 * * * *',
    $$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url')
              || '/functions/v1/execute-pending-payouts',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000
    )$$
);

