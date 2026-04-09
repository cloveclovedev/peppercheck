drop function if exists "public"."grant_subscription_points"(p_user_id uuid, p_amount integer, p_invoice_id text);

-- Add new enum value (ALTER TYPE ADD VALUE avoids dependency issues with functions using point_reason)
ALTER TYPE public.point_reason ADD VALUE IF NOT EXISTS 'plan_renewal_expiry' AFTER 'plan_renewal';

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.reset_subscription_points(p_user_id uuid, p_amount integer, p_invoice_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_ledger_id uuid;
    v_description text := 'Subscription renewal: ' || p_invoice_id;
    v_old_balance integer;
    v_old_locked integer;
    v_available integer;
BEGIN
    -- 1. Check if we already processed this invoice
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

    -- 2. Read current wallet state (FOR UPDATE to prevent concurrent lock_points race)
    SELECT balance, locked INTO v_old_balance, v_old_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        -- Fallback: Create wallet if it doesn't exist
        INSERT INTO public.point_wallets (user_id, balance)
        VALUES (p_user_id, p_amount);

        -- Insert renewal ledger entry
        INSERT INTO public.point_ledger (user_id, amount, reason, description, related_id)
        VALUES (p_user_id, p_amount, 'plan_renewal', v_description, null);

        RETURN true;
    END IF;

    -- 3. Record expiry of unused available points (if any)
    v_available := v_old_balance - v_old_locked;
    IF v_available > 0 THEN
        INSERT INTO public.point_ledger (user_id, amount, reason, description, related_id)
        VALUES (p_user_id, -v_available, 'plan_renewal_expiry', v_description, null);
    END IF;

    -- 4. Reset wallet: new balance = plan amount + locked
    UPDATE public.point_wallets
    SET balance = p_amount + v_old_locked,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- 5. Insert renewal ledger entry
    INSERT INTO public.point_ledger (user_id, amount, reason, description, related_id)
    VALUES (p_user_id, p_amount, 'plan_renewal', v_description, null);

    RETURN true;
END;
$function$
;


