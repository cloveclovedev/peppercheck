-- Snippet: Set up stripe_accounts row for account.updated webhook testing
--
-- Inserts or updates a stripe_accounts row with a known stripe_connect_account_id
-- so that the account.updated webhook handler can find and update it.
--
-- Prerequisites:
--   - User must exist in profiles table (sign up via app or create manually)
--   - Supabase local environment must be running (`supabase start`)
--
-- Usage:
--   1. Set v_user_id to an actual user ID from your local auth.users table
--   2. Set v_connect_account_id to a Stripe Connect account ID (from Stripe Dashboard or test mode)
--   3. Run this snippet via Supabase SQL Editor (http://127.0.0.1:54323)
--   4. Start webhook listener: stripe listen --forward-to http://127.0.0.1:54321/functions/v1/handle-stripe-webhook
--   5. Trigger event: stripe trigger account.updated
--      OR use Stripe Dashboard test mode to update the Connect account
--   6. Verify with the queries below

DO $$
DECLARE
    -- ========================================
    -- CONFIGURE THESE VALUES
    -- ========================================
    v_user_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual user ID
    v_connect_account_id text := 'acct_test123';              -- Replace with actual Connect account ID
    -- ========================================
BEGIN
    INSERT INTO public.stripe_accounts (profile_id, stripe_connect_account_id, charges_enabled, payouts_enabled)
    VALUES (v_user_id, v_connect_account_id, false, false)
    ON CONFLICT (profile_id) DO UPDATE SET
        stripe_connect_account_id = v_connect_account_id,
        charges_enabled = false,
        payouts_enabled = false,
        connect_requirements = NULL;

    RAISE NOTICE 'Inserted/updated stripe_accounts for user % with connect account %', v_user_id, v_connect_account_id;
    RAISE NOTICE '';
    RAISE NOTICE '--- Next steps ---';
    RAISE NOTICE '1. Start listener: stripe listen --forward-to http://127.0.0.1:54321/functions/v1/handle-stripe-webhook';
    RAISE NOTICE '2. Trigger: stripe trigger account.updated';
    RAISE NOTICE '3. Check results with the verification query below';
END;
$$;

-- =============================================
-- Verification query
-- =============================================

SELECT profile_id, stripe_connect_account_id, charges_enabled, payouts_enabled, connect_requirements, updated_at
FROM public.stripe_accounts
ORDER BY updated_at DESC
LIMIT 5;

-- =============================================
-- Cleanup (run after testing)
-- =============================================
-- UPDATE public.stripe_accounts
-- SET charges_enabled = false, payouts_enabled = false, connect_requirements = NULL
-- WHERE stripe_connect_account_id = 'acct_test123';
