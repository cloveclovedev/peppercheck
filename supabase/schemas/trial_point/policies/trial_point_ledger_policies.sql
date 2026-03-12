ALTER TABLE public.trial_point_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trial_point_ledger: select if self" ON public.trial_point_ledger
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
