-- Enum
CREATE TYPE public.evidence_status AS ENUM (
    'pending_upload',
    'ready'
);

-- Table: task_evidences
CREATE TABLE IF NOT EXISTS public.task_evidences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_id uuid NOT NULL,
    description text NOT NULL,
    status public.evidence_status DEFAULT 'pending_upload'::public.evidence_status NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.task_evidences OWNER TO postgres;

ALTER TABLE ONLY public.task_evidences
    ADD CONSTRAINT task_evidences_pkey PRIMARY KEY (id);

-- Indexes
CREATE INDEX idx_task_evidences_status ON public.task_evidences USING btree (status);
CREATE INDEX idx_task_evidences_task_id ON public.task_evidences USING btree (task_id);

COMMENT ON TABLE public.task_evidences IS 'Task-level evidence records shared across all referees';
COMMENT ON COLUMN public.task_evidences.status IS 'Upload status: pending_upload, ready';

ALTER TABLE ONLY public.task_evidences
    ADD CONSTRAINT task_evidences_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;
