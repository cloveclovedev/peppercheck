-- Device push-registration tokens, keyed unique on token (upsert conflict
-- target). Provider-neutral name: the value is currently an FCM registration
-- token, but the table models "a user's device push tokens" (a user has many).
-- A device re-logging-in rebinds its token to the new user via ON CONFLICT
-- (token). updated_at and last_active_at are Go-maintained on each upsert.
CREATE TABLE public.device_push_tokens (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    token          text NOT NULL,
    device_type    text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    last_active_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT device_push_tokens_token_key UNIQUE (token)
);

CREATE INDEX idx_device_push_tokens_user_id ON public.device_push_tokens (user_id);
CREATE INDEX idx_device_push_tokens_last_active_at ON public.device_push_tokens (last_active_at);
