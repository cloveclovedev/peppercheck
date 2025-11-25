-- Table: billing_settings
CREATE TABLE IF NOT EXISTS public.billing_settings (
    id smallint PRIMARY KEY DEFAULT 1,
    max_retry_attempts integer NOT NULL DEFAULT 3,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT billing_settings_singleton CHECK (id = 1)
);

COMMENT ON TABLE public.billing_settings IS 'Singleton configuration for billing behavior (e.g., retry limits).';
COMMENT ON COLUMN public.billing_settings.max_retry_attempts IS 'Maximum automatic retry attempts for billing_jobs before permanent failure.';
