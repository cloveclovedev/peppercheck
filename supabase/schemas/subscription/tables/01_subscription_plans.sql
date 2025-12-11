CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id text NOT NULL, -- 'light', 'standard', 'premium'
    name text NOT NULL,
    monthly_points integer NOT NULL CHECK (monthly_points >= 0),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT subscription_plans_pkey PRIMARY KEY (id)
);

ALTER TABLE public.subscription_plans OWNER TO postgres;

-- Policies
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "subscription_plans: read public" ON public.subscription_plans FOR SELECT USING (true);
