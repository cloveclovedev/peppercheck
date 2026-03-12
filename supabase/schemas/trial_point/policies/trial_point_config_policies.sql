ALTER TABLE public.trial_point_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trial_point_config: select all" ON public.trial_point_config
    FOR SELECT
    USING (true);
