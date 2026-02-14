ALTER TABLE public.reward_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reward_wallets: select if self" ON public.reward_wallets
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
