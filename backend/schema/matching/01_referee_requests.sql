-- A referee_request is one "seat" on a task: publishing a task creates N of
-- them (N = the tasker's chosen referee count), each matched asynchronously to
-- one available referee by the match_referee_request worker. matching_strategy
-- is a single value ('standard') in 4a; the enum leaves room for later
-- strategies. point_source / is_obligation are Phase 5 seams carried on the row
-- (no-op in 4a: point_source = 'regular', is_obligation = false). matched_referee_id
-- is nullable ON DELETE SET NULL for the Phase 6 deletion saga. updated_at is
-- Go-maintained (updated_at = now() on each UPDATE).
CREATE TYPE public.matching_strategy AS ENUM ('standard');

CREATE TYPE public.referee_request_status AS ENUM (
    'pending', 'accepted', 'expired', 'cancelled', 'closed', 'payment_processing'
);

-- point_source_type is shared with the Phase 5 point ledger; 4a only reads the
-- default. Defined here as the first consumer.
CREATE TYPE public.point_source_type AS ENUM ('regular', 'trial');

CREATE TABLE public.referee_requests (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id           uuid NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
    matching_strategy public.matching_strategy NOT NULL DEFAULT 'standard',
    status            public.referee_request_status NOT NULL DEFAULT 'pending',
    matched_referee_id uuid REFERENCES public.users (id) ON DELETE SET NULL,
    responded_at      timestamptz,
    point_source      public.point_source_type NOT NULL DEFAULT 'regular',
    is_obligation     boolean NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_referee_requests_task ON public.referee_requests (task_id);
CREATE INDEX idx_referee_requests_status ON public.referee_requests (status);
CREATE INDEX idx_referee_requests_matched ON public.referee_requests (matched_referee_id);

-- Concurrency guard (P4a-D16): a referee cannot hold two accepted seats on the
-- same task. The accept CAS relies on this partial unique index to make a
-- double-accept fail at the DB rather than in application logic.
CREATE UNIQUE INDEX uq_referee_requests_task_accepted_referee
    ON public.referee_requests (task_id, matched_referee_id)
    WHERE status = 'accepted' AND matched_referee_id IS NOT NULL;
