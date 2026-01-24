ALTER TABLE public.rating_histories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Rating Histories: insert if authenticated" ON public.rating_histories
FOR INSERT TO authenticated
WITH CHECK (true);

CREATE POLICY "Rating Histories: select if task participant" ON public.rating_histories
FOR SELECT TO authenticated
USING (((EXISTS (SELECT 1
   FROM public.tasks t
  WHERE ((t.id = rating_histories.task_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))) OR (EXISTS (SELECT 1
   FROM public.judgements j
     JOIN public.task_referee_requests trr ON j.id = trr.id
  WHERE ((trr.task_id = rating_histories.task_id) AND (trr.matched_referee_id = (SELECT auth.uid() AS uid)))))));
