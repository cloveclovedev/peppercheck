CREATE OR REPLACE FUNCTION public.deactivate_trial_points(
    p_user_id uuid
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_is_active boolean;
BEGIN
    SELECT is_active INTO v_is_active
    FROM public.trial_point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    -- No wallet = nothing to deactivate (existing user before feature launch)
    IF v_is_active IS NULL THEN
        RETURN;
    END IF;

    -- Already deactivated = idempotent
    IF NOT v_is_active THEN
        RETURN;
    END IF;

    UPDATE public.trial_point_wallets
    SET is_active = false,
        updated_at = now()
    WHERE user_id = p_user_id;

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description)
    VALUES (p_user_id, 0, 'subscription_deactivation'::public.trial_point_reason, 'Trial points deactivated on subscription start');
END;
$$;

ALTER FUNCTION public.deactivate_trial_points(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.deactivate_trial_points(uuid) IS 'Deactivates trial point wallet when user starts a subscription. Idempotent — safe to call multiple times. Balance is preserved for audit trail.';
