CREATE TABLE IF NOT EXISTS public.payout_topup_config (
    id boolean PRIMARY KEY DEFAULT true,
    buffer_multiplier numeric NOT NULL DEFAULT 1.3,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT singleton CHECK (id = true),
    CONSTRAINT buffer_multiplier_min CHECK (buffer_multiplier >= 1.0)
);

ALTER TABLE public.payout_topup_config OWNER TO postgres;

COMMENT ON TABLE public.payout_topup_config IS 'Singleton config for the payout top-up recommendation feature. buffer_multiplier scales projected month-end balance to determine recommended Stripe top-up amount.';
