CREATE TABLE IF NOT EXISTS public.point_wallets (
    user_id uuid NOT NULL,
    balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT point_wallets_pkey PRIMARY KEY (user_id),
    CONSTRAINT point_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.point_wallets OWNER TO postgres;

-- Policies (RLS)
ALTER TABLE public.point_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "point_wallets: select if self" ON public.point_wallets
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
