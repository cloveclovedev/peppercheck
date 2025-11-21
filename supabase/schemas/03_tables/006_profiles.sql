-- Table: profiles
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL,
    username text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now(),
    stripe_connect_account_id text,
    updated_at timestamp with time zone DEFAULT now(),
    timezone text DEFAULT 'UTC'::text
);

ALTER TABLE public.profiles OWNER TO postgres;

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_username_key UNIQUE (username);

-- Indexes
CREATE INDEX idx_profiles_timezone ON public.profiles USING btree (timezone);

COMMENT ON COLUMN public.profiles.timezone IS 'User timezone in IANA format (e.g., Asia/Tokyo, America/New_York, Europe/London)';
