-- Internal, provider-independent user anchor. FKs across the domain reference
-- users.id (never a provider UID). No provider column lives here; provider
-- links live in user_identities. updated_at is maintained by the Go store
-- (updated_at = now() on each UPDATE), not a DB trigger.
--
-- Numeric filename prefix: Atlas concatenates the .sql files in a directory
-- source in lexicographic filename order (it does not parse cross-file
-- dependencies), and "user_identities.sql" sorts before "users.sql" in plain
-- alphabetical order. The prefix forces this file, which user_identities
-- references via FK, to load first.
CREATE TABLE public.users (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    status     text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
