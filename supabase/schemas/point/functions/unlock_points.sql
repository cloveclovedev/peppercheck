CREATE OR REPLACE FUNCTION public.unlock_points(
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
    v_locked integer;
BEGIN
    -- Lock row and get current locked amount
    SELECT locked INTO v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_locked IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked points: requested %, locked %', p_amount, v_locked;
    END IF;

    -- Decrease locked amount (balance unchanged — points returned to available)
    UPDATE public.point_wallets
    SET locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Insert ledger entry (positive = points returned)
    INSERT INTO public.point_ledger (
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

ALTER FUNCTION public.unlock_points(uuid, integer, public.point_reason, text, uuid) OWNER TO postgres;
