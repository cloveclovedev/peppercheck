CREATE TABLE IF NOT EXISTS public.trial_point_wallets (
    user_id uuid NOT NULL,
    balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
    locked integer NOT NULL DEFAULT 0 CHECK (locked >= 0),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT trial_point_wallets_pkey PRIMARY KEY (user_id),
    CONSTRAINT trial_point_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT trial_point_wallets_balance_gte_locked CHECK (balance >= locked)
);

ALTER TABLE public.trial_point_wallets OWNER TO postgres;
