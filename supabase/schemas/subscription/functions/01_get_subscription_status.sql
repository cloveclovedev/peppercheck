CREATE OR REPLACE FUNCTION public.get_subscription_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

ALTER FUNCTION public.get_subscription_status() OWNER TO postgres;
