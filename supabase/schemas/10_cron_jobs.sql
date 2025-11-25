-- pg_cron jobs

-- Retries failed billing_jobs up to max_retry_attempts every hour.
SELECT cron.schedule(
  'billing_retry_hourly',
  '0 * * * *',
  $$SELECT public.retry_failed_billing_jobs();$$
);
