-- Table: billing_jobs
CREATE TABLE IF NOT EXISTS public.billing_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    referee_request_id uuid NOT NULL,
    status public.billing_job_status NOT NULL DEFAULT 'pending',
    currency_code text NOT NULL,
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    payment_provider text NOT NULL DEFAULT 'stripe',
    provider_payment_id text,
    attempt_count integer NOT NULL DEFAULT 0,
    last_error_code text,
    last_error_message text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT billing_jobs_pkey PRIMARY KEY (id),
    CONSTRAINT billing_jobs_referee_request_id_key UNIQUE (referee_request_id),
    CONSTRAINT billing_jobs_provider_payment_id_key UNIQUE (provider_payment_id)
);

ALTER TABLE public.billing_jobs OWNER TO postgres;

-- Indexes
CREATE INDEX idx_billing_jobs_status ON public.billing_jobs USING btree (status);
CREATE INDEX idx_billing_jobs_referee_request_id ON public.billing_jobs USING btree (referee_request_id);
CREATE INDEX idx_billing_jobs_currency_code ON public.billing_jobs USING btree (currency_code);
CREATE INDEX idx_billing_jobs_provider_payment_id ON public.billing_jobs USING btree (provider_payment_id);
