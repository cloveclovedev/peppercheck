CREATE OR REPLACE FUNCTION public.consume_points(
    p_user_id uuid,
    p_amount integer,
    p_reason public.point_reason,
    p_description text DEFAULT NULL,
    p_related_id uuid DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_balance integer;
    v_locked integer;
BEGIN
    -- Lock row and get current state
    SELECT balance, locked INTO v_balance, v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient points: required %, available %', p_amount, v_balance;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked points: required %, locked %', p_amount, v_locked;
    END IF;

    -- Settle: deduct from both balance and locked
    UPDATE public.point_wallets
    SET balance = balance - p_amount,
        locked = locked - p_amount,
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
        -p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$$;

ALTER FUNCTION public.consume_points(uuid, integer, public.point_reason, text, uuid) OWNER TO postgres;
