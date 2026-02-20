-- Snippet: Set up reward payout manual test scenario
--
-- Creates a pending payout record for a referee user so the
-- execute-pending-payouts Edge Function can be called manually.
--
-- Prerequisites:
--   - Referee user must exist in profiles table
--   - For full E2E test: Referee must have completed Stripe Connect payout setup
--     (stripe_accounts.payouts_enabled = true). Use the payout-setup flow in the app first.
--   - For testing the "skipped" path: use a referee WITHOUT Connect setup
--
-- Usage:
--   1. Set v_referee_id below to an actual referee user ID
--   2. Run this snippet via Supabase SQL Editor
--   3. Call the Edge Function (see curl command at the bottom)
--   4. Check results with the verification queries

DO $$
DECLARE
    -- ========================================
    -- CONFIGURE THIS VALUE
    -- ========================================
    v_referee_id uuid := '00000000-0000-0000-0000-000000000000'; -- Replace with actual referee user ID
    -- ========================================

    v_rate integer;
    v_balance integer := 5; -- Reward points to set (5 points = ¥250 at default rate)
    v_payout_id uuid;
BEGIN
    -- 1. Ensure reward wallet has balance
    INSERT INTO public.reward_wallets (user_id, balance)
    VALUES (v_referee_id, v_balance)
    ON CONFLICT (user_id) DO UPDATE SET balance = v_balance;

    RAISE NOTICE 'Set reward wallet balance to % points for user %', v_balance, v_referee_id;

    -- 2. Get exchange rate
    SELECT rate_per_point INTO v_rate
    FROM public.reward_exchange_rates
    WHERE currency = 'JPY' AND active = true;

    RAISE NOTICE 'Exchange rate: % JPY per point (total: ¥%)', v_rate, v_balance * v_rate;

    -- 3. Create pending payout record (bypasses month-end guard)
    INSERT INTO public.reward_payouts (
        user_id, points_amount, currency, currency_amount,
        rate_per_point, status, batch_date
    ) VALUES (
        v_referee_id, v_balance, 'JPY',
        v_balance * v_rate, v_rate, 'pending', CURRENT_DATE
    ) RETURNING id INTO v_payout_id;

    RAISE NOTICE 'Created pending payout: id=%, amount=¥%', v_payout_id, v_balance * v_rate;
    RAISE NOTICE '';
    RAISE NOTICE '--- Next steps ---';
    RAISE NOTICE '1. Run the Edge Function (see curl command below the snippet)';
    RAISE NOTICE '2. Check reward_payouts for status = success/failed';
    RAISE NOTICE '3. Check Stripe Dashboard > Connect > Transfers for the transfer';
END;
$$;

-- =============================================
-- Call the Edge Function (run in terminal)
-- =============================================
-- Replace <SERVICE_ROLE_KEY> with your local service role key (from `supabase status`)
--
-- curl -X POST http://127.0.0.1:54321/functions/v1/execute-pending-payouts \
--   -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
--   -H "Content-Type: application/json" \
--   -d '{}'

-- =============================================
-- Verification queries
-- =============================================

-- Check payout results
SELECT id, user_id, points_amount, currency_amount, status, stripe_transfer_id, error_message, batch_date
FROM public.reward_payouts
ORDER BY created_at DESC
LIMIT 5;

-- Check wallet balance (should be 0 after successful payout)
SELECT user_id, balance
FROM public.reward_wallets
WHERE balance > 0 OR user_id IN (SELECT user_id FROM public.reward_payouts WHERE batch_date = CURRENT_DATE);

-- Check ledger entries
SELECT user_id, amount, reason, description, created_at
FROM public.reward_ledger
WHERE reason = 'payout'
ORDER BY created_at DESC
LIMIT 5;

-- =============================================
-- Cleanup (run after testing)
-- =============================================
-- DELETE FROM public.reward_payouts WHERE batch_date = CURRENT_DATE;
-- UPDATE public.reward_wallets SET balance = 0;
-- DELETE FROM public.reward_ledger WHERE reason = 'payout';
