-- Durable job queue. The worker claims rows with FOR UPDATE SKIP LOCKED so
-- concurrent workers never process the same job. Each claim takes a lease
-- (locked_by token + lease_until); a running job whose lease expires (crashed
-- worker) is reclaimable. updated_at is set by the Go store (updated_at = now()
-- on each UPDATE), not a DB trigger.
CREATE TABLE public.jobs (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind            text NOT NULL,
    payload         jsonb NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key text UNIQUE,
    status          text NOT NULL DEFAULT 'pending',
    run_at          timestamptz NOT NULL DEFAULT now(),
    attempts        integer NOT NULL DEFAULT 0,
    max_attempts    integer NOT NULL DEFAULT 20,
    last_error      text,
    locked_at       timestamptz,
    locked_by       text,
    lease_until     timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT jobs_status_check CHECK (status IN ('pending', 'running', 'succeeded', 'failed'))
);

CREATE INDEX jobs_pending_run_at_idx ON public.jobs (run_at) WHERE status = 'pending';
CREATE INDEX jobs_running_lease_idx ON public.jobs (lease_until) WHERE status = 'running';
