-- FCM registration tokens, keyed unique on token (upsert conflict target). A
-- device re-logging-in rebinds its token to the new user via ON CONFLICT (token).
-- updated_at and last_active_at are Go-maintained on each upsert.
CREATE TABLE public.user_fcm_tokens (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    token          text NOT NULL,
    device_type    text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    last_active_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_fcm_tokens_token_key UNIQUE (token)
);

CREATE INDEX idx_user_fcm_tokens_user_id ON public.user_fcm_tokens (user_id);
CREATE INDEX idx_user_fcm_tokens_last_active_at ON public.user_fcm_tokens (last_active_at);
