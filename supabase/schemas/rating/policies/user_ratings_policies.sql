ALTER TABLE public.user_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_ratings: select for all" ON public.user_ratings
FOR SELECT
USING (true);
