CREATE OR REPLACE FUNCTION public.grant_reward(
    p_user_id uuid,
    p_amount integer,
    p_reason public.reward_reason,
    p_description text DEFAULT NULL,
    p_related_id uuid DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
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
$$;

ALTER FUNCTION public.grant_reward(uuid, integer, public.reward_reason, text, uuid) OWNER TO postgres;
