-- Test: prepare_monthly_payouts()
-- Run after db-reset to validate the prepare function.
-- NOTE: The function has a last-day-of-month guard.
-- To test on a non-last-day, temporarily comment out the guard.

-- 1. Verify exchange rate exists
SELECT * FROM public.reward_exchange_rates;
-- Expected: JPY | 50 | true

-- 2. Insert test reward wallets (simulate earned rewards)
INSERT INTO public.reward_wallets (user_id, balance)
SELECT id, 5  -- 5 points = 250 JPY
FROM auth.users
LIMIT 2
ON CONFLICT (user_id) DO UPDATE SET balance = 5;

-- 3. Call prepare function
SELECT public.prepare_monthly_payouts('JPY');

-- 4. Check results
SELECT id, user_id, points_amount, currency, currency_amount, rate_per_point, status, error_message, batch_date
FROM public.reward_payouts
ORDER BY created_at DESC;

-- 5. Verify idempotency (calling again should skip)
SELECT public.prepare_monthly_payouts('JPY');
-- Expected: {"skipped": true, "reason": "Payouts already prepared for ..."}

-- 6. Test deduct_reward_for_payout (for a specific payout)
-- SELECT public.deduct_reward_for_payout('<user_id>', 5, '<payout_id>');
-- Then check: SELECT * FROM public.reward_wallets WHERE user_id = '<user_id>';
-- And: SELECT * FROM public.reward_ledger WHERE reason = 'payout' ORDER BY created_at DESC;

-- Cleanup
DELETE FROM public.reward_payouts;
UPDATE public.reward_wallets SET balance = 0;
