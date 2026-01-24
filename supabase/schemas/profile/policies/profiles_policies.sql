ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles: public read" ON public.profiles
FOR SELECT
USING (true);

CREATE POLICY "Profiles: update if self" ON public.profiles
FOR UPDATE
USING ((id = (SELECT auth.uid() AS uid)));
