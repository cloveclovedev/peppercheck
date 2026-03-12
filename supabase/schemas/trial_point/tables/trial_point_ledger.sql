CREATE TABLE IF NOT EXISTS public.trial_point_ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount integer NOT NULL,
    reason public.trial_point_reason NOT NULL,
    description text,
    related_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT trial_point_ledger_pkey PRIMARY KEY (id),
    CONSTRAINT trial_point_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.trial_point_ledger OWNER TO postgres;

CREATE INDEX idx_trial_point_ledger_user_id ON public.trial_point_ledger USING btree (user_id);
CREATE INDEX idx_trial_point_ledger_created_at ON public.trial_point_ledger USING btree (created_at);
