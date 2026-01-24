ALTER TABLE public.stripe_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stripe_accounts: select if self" ON public.stripe_accounts
FOR SELECT
USING ((profile_id = (SELECT auth.uid() AS uid)));
