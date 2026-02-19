CREATE TYPE public.reward_payout_status AS ENUM (
    'pending',   -- Awaiting Stripe transfer
    'success',   -- Transfer completed
    'failed',    -- Transfer failed (balance preserved, retry next month)
    'skipped'    -- User not ready (no Connect account / payouts not enabled)
);

CREATE TABLE IF NOT EXISTS public.reward_payouts (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    points_amount integer NOT NULL,                           -- Points being paid out
    currency text NOT NULL,                                   -- 'JPY'
    currency_amount integer NOT NULL,                         -- Total payout in minor units (matches Stripe amount convention)
    rate_per_point integer NOT NULL,                          -- Snapshot of rate at time of payout (minor units)
    stripe_transfer_id text,                                  -- Stripe transfer ID on success
    status public.reward_payout_status NOT NULL DEFAULT 'pending',
    error_message text,                                       -- Error details on failure
    batch_date date NOT NULL,                                 -- Date payouts were prepared
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_payouts_pkey PRIMARY KEY (id),
    CONSTRAINT reward_payouts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

ALTER TABLE public.reward_payouts OWNER TO postgres;
