-- Daily sweep of stale R2 objects: expired evidence files (>= due_date + 90 days)
-- and orphan avatar objects (deleted-user prefixes + superseded versions for
-- live users).
--
-- service_role_key is used as the Bearer token because the function performs
-- admin reads on `profiles` that bypass RLS.
SELECT cron.schedule(
    'sweep-r2-stale-objects',
    '0 18 * * *',  -- daily 18:00 UTC = 03:00 JST (off-peak)
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
