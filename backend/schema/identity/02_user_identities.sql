-- Maps a verified external identity (issuer, subject) to the internal user.
-- Today subject holds the Firebase UID; the table can later hold real
-- per-provider subjects without touching users. updated_at is Go-maintained.
--
-- Numeric filename prefix: see 01_users.sql — this file must load after it
-- so the FK to public.users resolves in Atlas's dev-database diff.
CREATE TABLE public.user_identities (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    issuer     text NOT NULL,
    subject    text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_identities_issuer_subject_key UNIQUE (issuer, subject)
);

CREATE INDEX user_identities_user_id_idx
    ON public.user_identities (user_id);
