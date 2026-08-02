-- App-owned user profile (1:1 with the identity anchor). profiles.id IS users.id
-- (PK = FK); the API/DTO is idless. No Stripe column — payout/Stripe Connect
-- linkage is designed in Phase 5. updated_at is maintained by the Go store
-- (updated_at = now() on each UPDATE), not a DB trigger.
CREATE TABLE public.profiles (
    id         uuid PRIMARY KEY REFERENCES public.users (id) ON DELETE CASCADE,
    username   text NOT NULL,
    avatar_url text,
    timezone   text NOT NULL DEFAULT 'UTC',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT profiles_username_key UNIQUE (username),
    CONSTRAINT profiles_username_length CHECK (char_length(username) BETWEEN 2 AND 20)
);
