CREATE TABLE IF NOT EXISTS public.reward_exchange_rates (
    currency text NOT NULL,
    rate_per_point integer NOT NULL,                          -- Minor units per point (JPY: 50 = ¥50)
    active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_exchange_rates_pkey PRIMARY KEY (currency)
);

ALTER TABLE public.reward_exchange_rates OWNER TO postgres;
