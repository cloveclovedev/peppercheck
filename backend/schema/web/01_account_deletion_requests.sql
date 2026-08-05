-- Unverified account-deletion requests captured by the public (unauthenticated)
-- web resource. A row exists only when the claimed email matched a real account.
-- Phase 6 consumes these: email round-trip verification then the deletion saga.
-- updated_at is Go-maintained (updated_at = now() on UPDATE), not a DB trigger.
CREATE TABLE public.account_deletion_requests (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid NOT NULL UNIQUE REFERENCES public.users (id) ON DELETE CASCADE,
    claimed_email text NOT NULL,
    status        text NOT NULL DEFAULT 'unverified',
    source        text NOT NULL DEFAULT 'web',
    requested_at  timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
