CREATE TYPE public.point_reason AS ENUM (
    'plan_renewal',      -- Monthly subscription points grant
    'plan_upgrade',      -- Prorated points adjustment on upgrade
    'matching_request',  -- (Legacy) Consumed when requesting a referee matching
    'matching_lock',     -- Points locked when requesting a referee matching
    'matching_unlock',   -- Points unlocked (returned) on timeout
    'matching_settled',  -- Points consumed at Confirm
    'matching_refund',   -- Refunded if matching fails or task is cancelled
    'manual_adjustment', -- Admin operation/Support
    'referral_bonus'     -- Points earned from referring users
);

CREATE TABLE IF NOT EXISTS public.point_ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount integer NOT NULL, -- Can be negative (deduction) or positive (grant)
    reason public.point_reason NOT NULL,
    description text, -- Optional details
    related_id uuid, -- Optional polymorphic link to (billing_job_id, task_id, etc.)
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT point_ledger_pkey PRIMARY KEY (id),
    CONSTRAINT point_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.point_ledger OWNER TO postgres;

-- Indexes
CREATE INDEX idx_point_ledger_user_id ON public.point_ledger USING btree (user_id);
CREATE INDEX idx_point_ledger_created_at ON public.point_ledger USING btree (created_at);

