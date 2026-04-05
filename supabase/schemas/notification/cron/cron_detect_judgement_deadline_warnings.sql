SELECT cron.schedule(
    'detect-judgement-deadline-warnings',
    '* * * * *',
    $$SELECT public.detect_judgement_deadline_warnings()$$
);
