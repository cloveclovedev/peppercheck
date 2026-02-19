CREATE OR REPLACE FUNCTION public.deduct_reward_for_payout(
    p_user_id uuid,
    p_amount integer,
    p_payout_id uuid
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
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
$$;

ALTER FUNCTION public.deduct_reward_for_payout(uuid, integer, uuid) OWNER TO postgres;
