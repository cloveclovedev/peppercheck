-- Schedule monthly payout preparation on the last day of each month at 00:00 JST (15:00 UTC)
-- Runs on 28-31; the function has an internal guard to only execute on the actual last day
SELECT cron.schedule(
    'prepare-monthly-payouts',
    '0 15 28-31 * *',
    $$SELECT public.prepare_monthly_payouts('JPY')$$
);
