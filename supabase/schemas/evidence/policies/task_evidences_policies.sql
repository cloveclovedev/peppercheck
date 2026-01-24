ALTER TABLE public.task_evidences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Task Evidences: insert if tasker" ON public.task_evidences
FOR INSERT
WITH CHECK ((EXISTS (SELECT 1
   FROM public.tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))));

CREATE POLICY "Task Evidences: select if tasker or referee" ON public.task_evidences
FOR SELECT
USING (((EXISTS (SELECT 1
   FROM public.tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))) OR (EXISTS (SELECT 1
   FROM public.judgements j
     JOIN public.task_referee_requests trr ON j.id = trr.id
  WHERE ((trr.task_id = task_evidences.task_id) AND (trr.matched_referee_id = (SELECT auth.uid() AS uid)))))));

CREATE POLICY "Task Evidences: update if tasker" ON public.task_evidences
FOR UPDATE
USING ((EXISTS (SELECT 1
   FROM public.tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))));

CREATE POLICY "Task Evidences: delete if tasker" ON public.task_evidences
FOR DELETE
USING ((EXISTS (SELECT 1
   FROM public.tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))));
