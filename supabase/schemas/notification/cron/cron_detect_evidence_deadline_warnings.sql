SELECT cron.schedule(
    'detect-evidence-deadline-warnings',
    '* * * * *',
    $$SELECT public.detect_evidence_deadline_warnings()$$
);
