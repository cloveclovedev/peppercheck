-- Table: judgements
CREATE TABLE IF NOT EXISTS public.judgements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_id uuid NOT NULL,
    referee_id uuid NOT NULL,
    comment text,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_confirmed boolean DEFAULT false,
    reopen_count smallint DEFAULT 0 NOT NULL,
    is_evidence_timeout_confirmed boolean DEFAULT false NOT NULL,
    referee_request_id uuid
);

ALTER TABLE public.judgements OWNER TO postgres;

ALTER TABLE ONLY public.judgements
    ADD CONSTRAINT judgements_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.judgements
    ADD CONSTRAINT judgements_referee_request_id_key UNIQUE (referee_request_id);

-- Indexes
CREATE INDEX idx_judgements_evidence_timeout_confirmed ON public.judgements USING btree (is_evidence_timeout_confirmed) WHERE (status = 'evidence_timeout'::text);
CREATE INDEX idx_judgements_referee_id ON public.judgements USING btree (referee_id);
CREATE INDEX idx_judgements_task_id ON public.judgements USING btree (task_id);
CREATE INDEX idx_judgements_referee_request_id ON public.judgements USING btree (referee_request_id);

COMMENT ON COLUMN public.judgements.reopen_count IS 'Number of times this judgement has been reopened after rejection (operationally limited to 1; no DB-enforced cap)';
COMMENT ON COLUMN public.judgements.is_evidence_timeout_confirmed IS 'Indicates whether the referee has confirmed the evidence timeout. Used to trigger task_referee_request closure by the system.';
COMMENT ON COLUMN public.judgements.task_id IS 'Deprecated: kept for backward compatibility with clients; use referee_request_id for billing and relations.';
COMMENT ON COLUMN public.judgements.referee_id IS 'Deprecated: kept for backward compatibility with clients; use referee_request_id for billing and relations.';
COMMENT ON COLUMN public.judgements.referee_request_id IS '1:1 link to task_referee_requests; intended to be NOT NULL after backfill.';
