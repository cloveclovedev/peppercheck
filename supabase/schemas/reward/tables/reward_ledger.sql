CREATE TYPE public.reward_reason AS ENUM (
    'review_completed',   -- Reward for completing a review (Confirm)
    'evidence_timeout',   -- Reward when Tasker times out on evidence
    'payout',             -- Monthly payout to bank account
    'manual_adjustment'   -- Admin operation
);

CREATE TABLE IF NOT EXISTS public.reward_ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount integer NOT NULL,
    reason public.reward_reason NOT NULL,
    description text,
    related_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_ledger_pkey PRIMARY KEY (id),
    CONSTRAINT reward_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.reward_ledger OWNER TO postgres;

-- Indexes
CREATE INDEX idx_reward_ledger_user_id ON public.reward_ledger USING btree (user_id);
CREATE INDEX idx_reward_ledger_created_at ON public.reward_ledger USING btree (created_at);
