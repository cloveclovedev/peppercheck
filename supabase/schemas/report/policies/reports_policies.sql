ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reports: insert own" ON public.reports
    FOR INSERT
    WITH CHECK (reporter_id = (SELECT auth.uid()));

CREATE POLICY "reports: select own" ON public.reports
    FOR SELECT
    USING (reporter_id = (SELECT auth.uid()));
