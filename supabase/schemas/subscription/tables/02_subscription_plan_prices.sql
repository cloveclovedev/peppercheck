CREATE TABLE IF NOT EXISTS public.subscription_plan_prices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id text NOT NULL,
    currency_code text NOT NULL, -- 'JPY', 'USD'
    amount_minor integer NOT NULL CHECK (amount_minor >= 0),
    provider public.subscription_provider NOT NULL DEFAULT 'stripe', -- 'stripe', 'google', 'apple'
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT subscription_plan_prices_pkey PRIMARY KEY (id),
    CONSTRAINT subscription_plan_prices_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id) ON DELETE CASCADE,
    CONSTRAINT subscription_plan_prices_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) ON DELETE RESTRICT,
    CONSTRAINT subscription_plan_prices_unique_price UNIQUE (plan_id, currency_code, provider)
);

ALTER TABLE public.subscription_plan_prices OWNER TO postgres;

-- Policies
ALTER TABLE public.subscription_plan_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "subscription_plan_prices: read public" ON public.subscription_plan_prices FOR SELECT USING (true);
