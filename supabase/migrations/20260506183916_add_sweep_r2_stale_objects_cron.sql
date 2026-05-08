-- DML, not detected by schema diff.
-- Schedules the daily sweep of stale R2 objects (evidence retention +
-- avatar orphans). Canonical source: schemas/common/cron/cron_sweep_r2_stale_objects.sql
SELECT cron.schedule(
    'sweep-r2-stale-objects',
    '0 18 * * *',
    $$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url')
              || '/functions/v1/sweep-r2-stale-objects',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 300000
    )$$
);
