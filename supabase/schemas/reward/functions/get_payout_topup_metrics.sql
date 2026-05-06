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
