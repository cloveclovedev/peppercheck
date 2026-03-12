ALTER TABLE public.trial_point_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trial_point_wallets: select if self" ON public.trial_point_wallets
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
