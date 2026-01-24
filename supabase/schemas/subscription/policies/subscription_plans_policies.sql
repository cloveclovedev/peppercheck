ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "subscription_plans: read public" ON public.subscription_plans FOR SELECT USING (true);
