ALTER TABLE public.point_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "point_wallets: select if self" ON public.point_wallets
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
