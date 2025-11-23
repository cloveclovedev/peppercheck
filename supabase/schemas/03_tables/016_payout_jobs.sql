-- Table: payout_jobs
CREATE TABLE IF NOT EXISTS public.payout_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    status public.payout_job_status NOT NULL DEFAULT 'pending',
    currency_code text NOT NULL,
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    payment_provider text NOT NULL DEFAULT 'stripe',
    provider_payout_id text,
    attempt_count integer NOT NULL DEFAULT 0,
    last_error_code text,
    last_error_message text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT payout_jobs_pkey PRIMARY KEY (id),
    CONSTRAINT payout_jobs_provider_payout_id_key UNIQUE (provider_payout_id)
);

ALTER TABLE public.payout_jobs OWNER TO postgres;

-- Indexes
CREATE INDEX idx_payout_jobs_status ON public.payout_jobs USING btree (status);
CREATE INDEX idx_payout_jobs_user_id ON public.payout_jobs USING btree (user_id);
CREATE INDEX idx_payout_jobs_currency_code ON public.payout_jobs USING btree (currency_code);
CREATE INDEX idx_payout_jobs_provider_payout_id ON public.payout_jobs USING btree (provider_payout_id);
