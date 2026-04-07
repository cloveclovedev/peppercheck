CREATE OR REPLACE FUNCTION public.get_payment_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_points jsonb;
  v_trial_points jsonb;
  v_obligations_remaining integer;
  v_rewards jsonb;
  v_recent_payout jsonb;
  v_total_earned_minor bigint;
  v_total_earned_currency text;
  v_next_payout_date date;
BEGIN
  -- Tasker points (may not exist for new users)
  SELECT jsonb_build_object(
    'balance', pw.balance,
    'locked', pw.locked,
    'available', pw.balance - pw.locked
  )
  INTO v_points
  FROM public.point_wallets pw
  WHERE pw.user_id = v_user_id;

  IF v_points IS NULL THEN
    v_points := '{"balance": 0, "locked": 0, "available": 0}'::jsonb;
  END IF;

  -- Trial points (only if active)
  SELECT jsonb_build_object(
    'balance', tpw.balance,
    'locked', tpw.locked,
    'available', tpw.balance - tpw.locked
  )
  INTO v_trial_points
  FROM public.trial_point_wallets tpw
  WHERE tpw.user_id = v_user_id AND tpw.is_active = true;
  -- v_trial_points remains NULL if no active trial wallet

  -- Obligations remaining (independent of trial points — survives subscription)
  SELECT count(*)::integer
  INTO v_obligations_remaining
  FROM public.referee_obligations ro
  WHERE ro.user_id = v_user_id AND ro.status = 'pending';

  -- Rewards with exchange rate conversion
  SELECT jsonb_build_object(
    'balance', rw.balance,
    'currency_code', rer.currency,
    'currency_exponent', c.exponent,
    'amount_minor', rw.balance * rer.rate_per_point,
    'rate_per_point', rer.rate_per_point
  )
  INTO v_rewards
  FROM public.reward_wallets rw
  CROSS JOIN public.reward_exchange_rates rer
  JOIN public.currencies c ON c.code = rer.currency
  WHERE rw.user_id = v_user_id AND rer.active = true;
  -- v_rewards remains NULL if no reward wallet

  -- Most recent payout (includes currency exponent for formatting)
  SELECT jsonb_build_object(
    'amount_minor', rp.currency_amount,
    'currency_code', rp.currency,
    'currency_exponent', c.exponent,
    'status', rp.status,
    'batch_date', rp.batch_date
  )
  INTO v_recent_payout
  FROM public.reward_payouts rp
  JOIN public.currencies c ON c.code = rp.currency
  WHERE rp.user_id = v_user_id
  ORDER BY rp.created_at DESC
  LIMIT 1;
  -- v_recent_payout remains NULL if no payouts

  -- Total earned from successful payouts
  SELECT COALESCE(sum(rp.currency_amount), 0)::bigint
  INTO v_total_earned_minor
  FROM public.reward_payouts rp
  WHERE rp.user_id = v_user_id AND rp.status = 'success';

  -- Currency for total earned (active exchange rate currency)
  SELECT rer.currency
  INTO v_total_earned_currency
  FROM public.reward_exchange_rates rer
  WHERE rer.active = true
  LIMIT 1;

  -- Next payout date (last day of current month)
  v_next_payout_date := (date_trunc('month', now()) + interval '1 month - 1 day')::date;

  RETURN jsonb_build_object(
    'points', v_points,
    'trial_points', v_trial_points,
    'obligations_remaining', v_obligations_remaining,
    'rewards', v_rewards,
    'recent_payout', v_recent_payout,
    'total_earned_minor', v_total_earned_minor,
    'total_earned_currency', v_total_earned_currency,
    'next_payout_date', v_next_payout_date
  );
END;
$$;
