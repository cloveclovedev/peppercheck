ALTER TABLE public.reward_exchange_rates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reward_exchange_rates: select for authenticated" ON public.reward_exchange_rates
    FOR SELECT
    TO authenticated
    USING (true);
