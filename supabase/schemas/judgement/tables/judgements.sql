-- Table: judgements
-- Moving from 002_judgements.sql to schemas/judgement/tables/judgements.sql

-- Status Enum
CREATE TYPE public.judgement_status AS ENUM (
    'awaiting_evidence',
    'in_review',
    'approved',
    'rejected',
    'review_timeout',
    'evidence_timeout'
);

CREATE TABLE IF NOT EXISTS public.judgements (
    id uuid NOT NULL REFERENCES public.task_referee_requests(id) ON DELETE CASCADE,
    
    -- Status & Content
    status judgement_status DEFAULT 'awaiting_evidence'::judgement_status NOT NULL,
    comment text,
    
    -- Workflow Flags
    is_confirmed boolean DEFAULT false,
    reopen_count smallint DEFAULT 0 NOT NULL,
    is_evidence_timeout_confirmed boolean DEFAULT false NOT NULL,
    
    -- Timestamps
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),

    CONSTRAINT judgements_pkey PRIMARY KEY (id)
);

ALTER TABLE public.judgements OWNER TO postgres;

-- Indexes
CREATE INDEX idx_judgements_evidence_timeout_confirmed ON public.judgements USING btree (is_evidence_timeout_confirmed) WHERE (status = 'evidence_timeout'::judgement_status);
-- No need for request_id or task_id indexes as id is the FK and PK.

COMMENT ON TABLE public.judgements IS 'Stores judgement decisions. ID is strictly 1:1 with task_referee_requests.id.';
COMMENT ON COLUMN public.judgements.id IS 'Foreign Key to task_referee_requests.id. Ensures 1:1 relationship.';
COMMENT ON COLUMN public.judgements.reopen_count IS 'Number of times this judgement has been reopened.';
COMMENT ON COLUMN public.judgements.is_evidence_timeout_confirmed IS 'Indicates whether the referee has confirmed the evidence timeout.';


