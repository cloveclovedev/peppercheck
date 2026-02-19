-- Schedule review timeout detection every 5 minutes
-- pg_cron extension is enabled in extensions.sql
SELECT cron.schedule(
    'detect-review-timeouts',
    '*/5 * * * *',
    $$SELECT public.detect_and_handle_review_timeouts()$$
);
