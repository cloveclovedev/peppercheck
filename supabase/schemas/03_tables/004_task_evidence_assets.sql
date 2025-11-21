-- Table: task_evidence_assets
CREATE TABLE IF NOT EXISTS public.task_evidence_assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    evidence_id uuid NOT NULL,
    file_url text NOT NULL,
    file_size_bytes bigint,
    content_type text,
    created_at timestamp with time zone DEFAULT now(),
    public_url text,
    processing_status text DEFAULT 'pending'::text,
    error_message text
);

ALTER TABLE public.task_evidence_assets OWNER TO postgres;

ALTER TABLE ONLY public.task_evidence_assets
    ADD CONSTRAINT task_evidence_assets_pkey PRIMARY KEY (id);
    
-- Indexes
CREATE INDEX idx_task_evidence_assets_evidence_id ON public.task_evidence_assets USING btree (evidence_id);
CREATE INDEX idx_task_evidence_assets_processing_status ON public.task_evidence_assets USING btree (processing_status);
CREATE INDEX idx_task_evidence_assets_public_url ON public.task_evidence_assets USING btree (public_url);
