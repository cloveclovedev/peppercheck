ALTER TABLE public.reward_payouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reward_payouts: select if self" ON public.reward_payouts
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
