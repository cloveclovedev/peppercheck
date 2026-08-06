-- A judgement is created (status 'awaiting_evidence') by the matching worker the
-- moment a referee accepts a request; its full lifecycle (evidence review,
-- confirm, reopen, auto-confirm, timeouts) is Phase 4c. The PK IS the
-- referee_request id (1:1, PK = FK) and cascades from it. In 4a only the
-- awaiting_evidence row is provisioned/removed; the remaining columns are
-- forward-built for 4c. updated_at is Go-maintained (updated_at = now() on each
-- UPDATE).
CREATE TYPE public.judgement_status AS ENUM (
    'awaiting_evidence', 'in_review', 'approved', 'rejected',
    'review_timeout', 'evidence_timeout'
);

CREATE TABLE public.judgements (
    id                uuid PRIMARY KEY REFERENCES public.referee_requests (id) ON DELETE CASCADE,
    status            public.judgement_status NOT NULL DEFAULT 'awaiting_evidence',
    comment           text,
    is_confirmed      boolean NOT NULL DEFAULT false,
    is_auto_confirmed boolean NOT NULL DEFAULT false,
    reopen_count      smallint NOT NULL DEFAULT 0,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
