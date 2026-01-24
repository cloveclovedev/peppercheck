ALTER TABLE public.referee_available_time_slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "referee_available_time_slots: insert for own records" ON public.referee_available_time_slots
FOR INSERT
WITH CHECK ((user_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "referee_available_time_slots: select for all" ON public.referee_available_time_slots
FOR SELECT
USING (true);

CREATE POLICY "referee_available_time_slots: update for own records" ON public.referee_available_time_slots
FOR UPDATE
USING ((user_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "referee_available_time_slots: delete for own records" ON public.referee_available_time_slots
FOR DELETE
USING ((user_id = (SELECT auth.uid() AS uid)));
