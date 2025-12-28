-- Table: matching_config
CREATE TABLE IF NOT EXISTS public.matching_config (
    key text NOT NULL,
    value jsonb NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT matching_config_pkey PRIMARY KEY (key)
);

ALTER TABLE public.matching_config OWNER TO postgres;

-- Policies
ALTER TABLE public.matching_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "matching_config: read public" ON public.matching_config
    FOR SELECT
    USING (true);

