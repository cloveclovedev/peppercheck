-- Execute pending payouts every 30 minutes via Edge Function
-- No-op when no pending records exist
SELECT cron.schedule(
    'execute-pending-payouts',
    '*/30 * * * *',
    $$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url')
              || '/functions/v1/execute-pending-payouts',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000
    )$$
);
