
  create table "public"."payout_topup_config" (
    "id" boolean not null default true,
    "buffer_multiplier" numeric not null default 1.3,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."payout_topup_config" enable row level security;

CREATE UNIQUE INDEX payout_topup_config_pkey ON public.payout_topup_config USING btree (id);

alter table "public"."payout_topup_config" add constraint "payout_topup_config_pkey" PRIMARY KEY using index "payout_topup_config_pkey";

alter table "public"."payout_topup_config" add constraint "buffer_multiplier_min" CHECK ((buffer_multiplier >= 1.0)) not valid;

alter table "public"."payout_topup_config" validate constraint "buffer_multiplier_min";

alter table "public"."payout_topup_config" add constraint "singleton" CHECK ((id = true)) not valid;

alter table "public"."payout_topup_config" validate constraint "singleton";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_payout_topup_metrics(p_currency text DEFAULT 'JPY'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_rate integer;
    v_total_obligation_pts numeric;
    v_mtd_earnings_pts numeric;
    v_buffer_multiplier numeric;
    v_month_start_jst timestamptz;
BEGIN
    -- Get active exchange rate
    SELECT rate_per_point INTO v_rate
    FROM public.reward_exchange_rates
    WHERE currency = p_currency AND active = true;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'No active exchange rate for currency: %', p_currency;
    END IF;

    -- Sum of all wallet balances (carry-over from prior months + current)
    SELECT COALESCE(SUM(balance), 0) INTO v_total_obligation_pts
    FROM public.reward_wallets;

    -- Beginning of current month in Asia/Tokyo, then back to timestamptz
    v_month_start_jst := (date_trunc('month', (now() AT TIME ZONE 'Asia/Tokyo')))
                         AT TIME ZONE 'Asia/Tokyo';

    -- Month-to-date positive earnings (only earning reasons, not payouts)
    SELECT COALESCE(SUM(amount), 0) INTO v_mtd_earnings_pts
    FROM public.reward_ledger
    WHERE reason IN ('review_completed', 'evidence_timeout', 'manual_adjustment')
      AND amount > 0
      AND created_at >= v_month_start_jst;

    -- Singleton config row
    SELECT buffer_multiplier INTO v_buffer_multiplier
    FROM public.payout_topup_config
    WHERE id = true;

    IF v_buffer_multiplier IS NULL THEN
        RAISE EXCEPTION 'payout_topup_config singleton row missing';
    END IF;

    RETURN jsonb_build_object(
        'currency', p_currency,
        'rate_per_point', v_rate,
        'total_obligation_jpy', v_total_obligation_pts * v_rate,
        'month_to_date_earnings_jpy', v_mtd_earnings_pts * v_rate,
        'buffer_multiplier', v_buffer_multiplier
    );
END;
$function$
;

grant delete on table "public"."payout_topup_config" to "anon";

grant insert on table "public"."payout_topup_config" to "anon";

grant references on table "public"."payout_topup_config" to "anon";

grant select on table "public"."payout_topup_config" to "anon";

grant trigger on table "public"."payout_topup_config" to "anon";

grant truncate on table "public"."payout_topup_config" to "anon";

grant update on table "public"."payout_topup_config" to "anon";

grant delete on table "public"."payout_topup_config" to "authenticated";

grant insert on table "public"."payout_topup_config" to "authenticated";

grant references on table "public"."payout_topup_config" to "authenticated";

grant select on table "public"."payout_topup_config" to "authenticated";

grant trigger on table "public"."payout_topup_config" to "authenticated";

grant truncate on table "public"."payout_topup_config" to "authenticated";

grant update on table "public"."payout_topup_config" to "authenticated";

grant delete on table "public"."payout_topup_config" to "service_role";

grant insert on table "public"."payout_topup_config" to "service_role";

grant references on table "public"."payout_topup_config" to "service_role";

grant select on table "public"."payout_topup_config" to "service_role";

grant trigger on table "public"."payout_topup_config" to "service_role";

grant truncate on table "public"."payout_topup_config" to "service_role";

grant update on table "public"."payout_topup_config" to "service_role";

CREATE TRIGGER on_payout_topup_config_update_set_updated_at BEFORE UPDATE ON public.payout_topup_config FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- DML, not detected by schema diff
INSERT INTO public.payout_topup_config (id) VALUES (true)
ON CONFLICT (id) DO NOTHING;
