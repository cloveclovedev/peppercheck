CREATE TABLE IF NOT EXISTS public.reward_wallets (
    user_id uuid NOT NULL,
    balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_wallets_pkey PRIMARY KEY (user_id),
    CONSTRAINT reward_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.reward_wallets OWNER TO postgres;
