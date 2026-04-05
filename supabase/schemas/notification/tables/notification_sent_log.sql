CREATE TABLE IF NOT EXISTS public.notification_sent_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    judgement_id uuid NOT NULL,
    notification_key text NOT NULL,
    reminder_minutes integer NOT NULL,
    sent_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.notification_sent_log OWNER TO postgres;

ALTER TABLE ONLY public.notification_sent_log
    ADD CONSTRAINT notification_sent_log_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.notification_sent_log
    ADD CONSTRAINT notification_sent_log_judgement_id_fkey
    FOREIGN KEY (judgement_id) REFERENCES public.judgements(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX idx_notification_sent_log_unique
    ON public.notification_sent_log (judgement_id, notification_key, reminder_minutes);

ALTER TABLE public.notification_sent_log ENABLE ROW LEVEL SECURITY;
