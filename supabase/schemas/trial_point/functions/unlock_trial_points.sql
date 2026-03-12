CREATE OR REPLACE FUNCTION public.unlock_trial_points(
    p_user_id uuid,
    p_amount integer,
    p_reason public.trial_point_reason,
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
    SELECT locked INTO v_locked
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_locked IS NULL THEN
        RAISE EXCEPTION 'Trial point wallet not found for user %', p_user_id;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked trial points: requested %, locked %', p_amount, v_locked;
    END IF;

    UPDATE public.trial_point_wallets
    SET locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description, related_id)
    VALUES (p_user_id, p_amount, p_reason, p_description, p_related_id);
END;
$$;

ALTER FUNCTION public.unlock_trial_points(uuid, integer, public.trial_point_reason, text, uuid) OWNER TO postgres;
