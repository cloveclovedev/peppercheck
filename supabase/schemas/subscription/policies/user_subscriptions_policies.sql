ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_subscriptions: select if self" ON public.user_subscriptions
    FOR SELECT
    USING (auth.uid() = user_id);
