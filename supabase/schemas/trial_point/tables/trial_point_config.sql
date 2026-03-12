CREATE TABLE IF NOT EXISTS public.trial_point_config (
    id boolean PRIMARY KEY DEFAULT true,
    initial_grant_amount integer NOT NULL DEFAULT 3,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT singleton CHECK (id = true)
);

ALTER TABLE public.trial_point_config OWNER TO postgres;

COMMENT ON TABLE public.trial_point_config IS 'Singleton config for trial point settings. initial_grant_amount controls how many trial points new users receive on registration.';
