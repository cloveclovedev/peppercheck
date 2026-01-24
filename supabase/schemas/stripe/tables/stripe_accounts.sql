-- Table: stripe_accounts
CREATE TABLE IF NOT EXISTS public.stripe_accounts (
    profile_id uuid NOT NULL,
    stripe_customer_id text,
    stripe_connect_account_id text,
    charges_enabled boolean DEFAULT false,
    payouts_enabled boolean DEFAULT false,
    connect_requirements jsonb,
    default_payment_method_id text,
    pm_brand text,
    pm_last4 text,
    pm_exp_month integer,
    pm_exp_year integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.stripe_accounts OWNER TO postgres;

ALTER TABLE ONLY public.stripe_accounts
    ADD CONSTRAINT stripe_accounts_pkey PRIMARY KEY (profile_id);

ALTER TABLE ONLY public.stripe_accounts
    ADD CONSTRAINT stripe_accounts_stripe_customer_id_key UNIQUE (stripe_customer_id);

ALTER TABLE ONLY public.stripe_accounts
    ADD CONSTRAINT stripe_accounts_stripe_connect_account_id_key UNIQUE (stripe_connect_account_id);

ALTER TABLE ONLY public.stripe_accounts
    ADD CONSTRAINT stripe_accounts_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
