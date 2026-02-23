-- Schedule auto-confirm detection every hour
-- pg_cron extension is enabled in extensions.sql
SELECT cron.schedule(
    'detect-auto-confirms',
    '0 * * * *',
    $$SELECT public.detect_auto_confirms()$$
);
