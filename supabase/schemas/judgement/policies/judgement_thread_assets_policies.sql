ALTER TABLE public.judgement_thread_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Thread Assets: insert if participant" ON public.judgement_thread_assets
FOR INSERT
WITH CHECK ((EXISTS (SELECT 1
   FROM ((public.judgement_threads jt
     JOIN public.judgements j ON ((jt.judgement_id = j.id)))
     JOIN public.task_referee_requests trr ON ((j.id = trr.id))
     JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND ((t.tasker_id = (SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = (SELECT auth.uid() AS uid)))))));

CREATE POLICY "Thread Assets: select if participant" ON public.judgement_thread_assets
FOR SELECT
USING ((EXISTS (SELECT 1
   FROM ((public.judgement_threads jt
     JOIN public.judgements j ON ((jt.judgement_id = j.id)))
     JOIN public.task_referee_requests trr ON ((j.id = trr.id))
     JOIN public.tasks t ON ((trr.task_id = t.id)))
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND ((t.tasker_id = (SELECT auth.uid() AS uid)) OR (trr.matched_referee_id = (SELECT auth.uid() AS uid)))))));

CREATE POLICY "Thread Assets: update if sender" ON public.judgement_thread_assets
FOR UPDATE
USING ((EXISTS (SELECT 1
   FROM public.judgement_threads jt
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND (jt.sender_id = (SELECT auth.uid() AS uid))))));

CREATE POLICY "Thread Assets: delete if sender" ON public.judgement_thread_assets
FOR DELETE
USING ((EXISTS (SELECT 1
   FROM public.judgement_threads jt
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND (jt.sender_id = (SELECT auth.uid() AS uid))))));
