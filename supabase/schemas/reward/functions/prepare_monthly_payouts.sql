CREATE OR REPLACE FUNCTION public.prepare_monthly_payouts(
    p_currency text DEFAULT 'JPY'
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
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
    IF EXISTS (SELECT 1 FROM public.reward_payouts WHERE batch_date = v_batch_date AND currency = p_currency LIMIT 1) THEN
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
$$;

ALTER FUNCTION public.prepare_monthly_payouts(text) OWNER TO postgres;
