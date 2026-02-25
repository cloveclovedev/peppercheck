CREATE TABLE IF NOT EXISTS public.matching_time_config (
    id boolean PRIMARY KEY DEFAULT true,
    open_deadline_hours int NOT NULL,
    cancel_deadline_hours int NOT NULL,
    rematch_cutoff_hours int NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT singleton CHECK (id = true),
    CONSTRAINT cancel_deadline_positive CHECK (cancel_deadline_hours > 0),
    CONSTRAINT ordering_invariant CHECK (
        open_deadline_hours > rematch_cutoff_hours
        AND rematch_cutoff_hours > cancel_deadline_hours
    )
);

ALTER TABLE public.matching_time_config OWNER TO postgres;

ALTER TABLE public.matching_time_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "matching_time_config: read public"
    ON public.matching_time_config FOR SELECT USING (true);
