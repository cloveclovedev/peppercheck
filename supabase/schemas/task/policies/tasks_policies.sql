ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tasks: insert if authenticated" ON public.tasks
FOR INSERT
WITH CHECK ((tasker_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "Tasks: select if tasker, referee, or referee candidate" ON public.tasks
FOR SELECT
USING (((tasker_id = (SELECT auth.uid() AS uid)) OR public.is_task_referee(id, (SELECT auth.uid() AS uid)) OR public.is_task_referee_candidate(id, (SELECT auth.uid() AS uid))));

CREATE POLICY "Tasks: update if tasker" ON public.tasks
FOR UPDATE
USING ((tasker_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "Tasks: delete if tasker" ON public.tasks
FOR DELETE
USING ((tasker_id = (SELECT auth.uid() AS uid)));

COMMENT ON POLICY "Tasks: select if tasker, referee, or referee candidate" ON public.tasks IS 'Allow access to task details for taskers, assigned referees, and referee candidates. Referee candidates can only see task information, not judgements or evidences.';
