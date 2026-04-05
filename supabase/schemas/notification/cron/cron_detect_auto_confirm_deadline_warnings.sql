SELECT cron.schedule(
    'detect-auto-confirm-deadline-warnings',
    '* * * * *',
    $$SELECT public.detect_auto_confirm_deadline_warnings()$$
);
