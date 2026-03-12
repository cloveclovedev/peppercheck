ALTER TABLE public.referee_obligations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "referee_obligations: select if self" ON public.referee_obligations
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
