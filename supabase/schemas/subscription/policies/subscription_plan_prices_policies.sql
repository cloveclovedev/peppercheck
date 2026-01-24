ALTER TABLE public.subscription_plan_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "subscription_plan_prices: read public" ON public.subscription_plan_prices FOR SELECT USING (true);
