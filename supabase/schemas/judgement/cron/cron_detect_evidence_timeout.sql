-- Schedule evidence timeout detection every 5 minutes
-- pg_cron extension is enabled in extensions.sql
SELECT cron.schedule(
    'detect-evidence-timeouts',
    '*/5 * * * *',
    $$SELECT public.detect_and_handle_evidence_timeouts()$$
);
