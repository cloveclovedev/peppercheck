ALTER TABLE public.task_evidence_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Task Evidence Assets: insert if tasker" ON public.task_evidence_assets
FOR INSERT
WITH CHECK ((EXISTS (SELECT 1
   FROM (public.task_evidences te
     JOIN public.tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))));

CREATE POLICY "Task Evidence Assets: select if tasker or referee" ON public.task_evidence_assets
FOR SELECT
USING (((EXISTS (SELECT 1
   FROM (public.task_evidences te
     JOIN public.tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))) OR (EXISTS (SELECT 1
   FROM (public.task_evidences te
     JOIN public.task_referee_requests trr ON ((trr.task_id = te.task_id))
     JOIN public.judgements j ON ((j.id = trr.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) 
    AND (trr.matched_referee_id = (SELECT auth.uid() AS uid)))))));

CREATE POLICY "Task Evidence Assets: update if tasker" ON public.task_evidence_assets
FOR UPDATE
USING ((EXISTS (SELECT 1
   FROM (public.task_evidences te
     JOIN public.tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))));

CREATE POLICY "Task Evidence Assets: delete if tasker" ON public.task_evidence_assets
FOR DELETE
USING ((EXISTS (SELECT 1
   FROM (public.task_evidences te
     JOIN public.tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = (SELECT auth.uid() AS uid))))));
