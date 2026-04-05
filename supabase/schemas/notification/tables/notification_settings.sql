CREATE TABLE IF NOT EXISTS public.notification_settings (
    user_id uuid NOT NULL,
    evidence_reminder_minutes integer[] DEFAULT '{10}',
    judgement_reminder_minutes integer[] DEFAULT '{10}',
    auto_confirm_reminder_minutes integer[] DEFAULT NULL,
    evidence_reminder_even_if_submitted boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.notification_settings OWNER TO postgres;

ALTER TABLE ONLY public.notification_settings
    ADD CONSTRAINT notification_settings_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.notification_settings
    ADD CONSTRAINT notification_settings_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
