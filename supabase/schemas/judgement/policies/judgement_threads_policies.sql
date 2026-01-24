ALTER TABLE public.judgement_threads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Threads: insert if participant" ON public.judgement_threads
FOR INSERT
WITH CHECK ((EXISTS (SELECT 1
   FROM (public.judgements j
     JOIN public.task_referee_requests trr ON j.id = trr.id
     JOIN public.tasks t ON trr.task_id = t.id)
  WHERE ((j.id = judgement_threads.judgement_id) AND ((t.tasker_id = (SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = (SELECT auth.uid() AS uid)))))));

CREATE POLICY "Threads: select if participant" ON public.judgement_threads
FOR SELECT
USING ((EXISTS (SELECT 1
   FROM (public.judgements j
     JOIN public.task_referee_requests trr ON j.id = trr.id
     JOIN public.tasks t ON trr.task_id = t.id)
  WHERE ((j.id = judgement_threads.judgement_id) AND ((t.tasker_id = (SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = (SELECT auth.uid() AS uid)))))));

CREATE POLICY "Threads: update if sender" ON public.judgement_threads
FOR UPDATE
USING ((sender_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "Threads: delete if sender" ON public.judgement_threads
FOR DELETE
USING ((sender_id = (SELECT auth.uid() AS uid)));
