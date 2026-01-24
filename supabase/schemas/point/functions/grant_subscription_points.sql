-- Function to grant points for subscription renewal idempotently
-- Returns true if points were granted, false if already processed based on invoice_id
CREATE OR REPLACE FUNCTION public.grant_subscription_points(
    p_user_id uuid,
    p_amount integer,
    p_invoice_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
    v_ledger_id uuid;
    v_description text := 'Subscription renewal: ' || p_invoice_id;
BEGIN
    -- 1. Check if we already processed this invoice
    -- We use the description field to store the invoice ID reference
    SELECT id INTO v_ledger_id
    FROM public.point_ledger
    WHERE user_id = p_user_id
    AND reason = 'plan_renewal'
    AND description = v_description
    LIMIT 1;

    IF v_ledger_id IS NOT NULL THEN
        -- Already processed
        RETURN false;
    END IF;

    -- 2. Update Wallet (Create if not exists - defensive programming)
    -- Try update first
    UPDATE public.point_wallets
    SET balance = balance + p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        -- Fallback: Create wallet if it doesn't exist (shouldn't happen for valid users but safe to have)
        INSERT INTO public.point_wallets (user_id, balance)
        VALUES (p_user_id, p_amount);
    END IF;

    -- 3. specific Insert Ledger Entry
    INSERT INTO public.point_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        p_amount,
        'plan_renewal',
        v_description,
        null
    );

    RETURN true;
END;
$$;

ALTER FUNCTION public.grant_subscription_points(uuid, integer, text) OWNER TO postgres;
