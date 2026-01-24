CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    user_id uuid NOT NULL,
    plan_id text NOT NULL,
    status public.subscription_status NOT NULL,
    provider public.subscription_provider NOT NULL,
    
    -- External IDs
    stripe_subscription_id text,
    google_purchase_token text,
    
    current_period_start timestamp with time zone NOT NULL,
    current_period_end timestamp with time zone NOT NULL,
    
    cancel_at_period_end boolean DEFAULT false NOT NULL,
    
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    
    CONSTRAINT user_subscriptions_pkey PRIMARY KEY (user_id),
    CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT user_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id)
);

ALTER TABLE public.user_subscriptions OWNER TO postgres;

-- Indexes
CREATE INDEX idx_user_subscriptions_stripe_id ON public.user_subscriptions USING btree (stripe_subscription_id);
CREATE INDEX idx_user_subscriptions_provider ON public.user_subscriptions USING btree (provider, status);

