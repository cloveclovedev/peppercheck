-- Schedule pending request processing every hour
-- pg_cron extension is enabled in extensions.sql
SELECT cron.schedule(
    'process-pending-requests',
    '0 * * * *',
    $$SELECT public.process_pending_requests()$$
);
