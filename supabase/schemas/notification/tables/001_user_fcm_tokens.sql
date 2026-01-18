-- Table: user_fcm_tokens
-- Located in supabase/schemas/notification/tables/001_user_fcm_tokens.sql

CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    device_type text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_active_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.user_fcm_tokens OWNER TO postgres;

ALTER TABLE ONLY public.user_fcm_tokens
    ADD CONSTRAINT user_fcm_tokens_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.user_fcm_tokens
    ADD CONSTRAINT user_fcm_tokens_token_key UNIQUE (token);

ALTER TABLE ONLY public.user_fcm_tokens
    ADD CONSTRAINT user_fcm_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Indexes
CREATE INDEX idx_user_fcm_tokens_user_id ON public.user_fcm_tokens USING btree (user_id);
CREATE INDEX idx_user_fcm_tokens_last_active ON public.user_fcm_tokens USING btree (last_active_at);

-- RLS
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own tokens" ON public.user_fcm_tokens
    FOR SELECT
    USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert their own tokens" ON public.user_fcm_tokens
    FOR INSERT
    WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update their own tokens" ON public.user_fcm_tokens
    FOR UPDATE
    USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete their own tokens" ON public.user_fcm_tokens
    FOR DELETE
    USING ((select auth.uid()) = user_id);



COMMENT ON TABLE public.user_fcm_tokens IS 'Stores FCM registration tokens for users to receive push notifications. Linked to auth.users for cascading deletes.';
