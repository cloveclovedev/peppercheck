CREATE OR REPLACE FUNCTION public.consume_trial_points(
    p_user_id uuid,
    p_amount integer,
    p_reason public.trial_point_reason DEFAULT 'matching_settled',
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
    v_i integer;
BEGIN
    SELECT balance, locked INTO v_balance, v_locked
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Trial point wallet not found for user %', p_user_id;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient trial points: required %, available %', p_amount, v_balance;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked trial points: required %, locked %', p_amount, v_locked;
    END IF;

    UPDATE public.trial_point_wallets
    SET balance = balance - p_amount,
        locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description, related_id)
    VALUES (p_user_id, -p_amount, p_reason, p_description, p_related_id);

    -- Create referee obligations (1 per point consumed).
    -- p_amount is typically 1 (one point per matching strategy),
    -- but loop handles the general case per spec: "1 trial point consumed = 1 referee obligation".
    FOR v_i IN 1..p_amount LOOP
        INSERT INTO public.referee_obligations (user_id, source_request_id)
        VALUES (p_user_id, p_related_id);
    END LOOP;
END;
$$;

ALTER FUNCTION public.consume_trial_points(uuid, integer, public.trial_point_reason, text, uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.consume_trial_points(uuid, integer, public.trial_point_reason, text, uuid) IS 'Consumes locked trial points and creates referee obligations (1 per point). Called at judgement confirmation or evidence timeout for trial-funded requests.';
