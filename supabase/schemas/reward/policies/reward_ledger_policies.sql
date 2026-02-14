ALTER TABLE public.reward_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reward_ledger: select if self" ON public.reward_ledger
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
