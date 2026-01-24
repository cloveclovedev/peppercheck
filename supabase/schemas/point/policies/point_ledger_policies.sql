ALTER TABLE public.point_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "point_ledger: select if self" ON public.point_ledger
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
