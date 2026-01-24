ALTER TABLE public.task_referee_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_referee_requests: insert if tasker" ON public.task_referee_requests
FOR INSERT
WITH CHECK ((task_id IN (SELECT tasks.id
   FROM public.tasks
  WHERE (tasks.tasker_id = (SELECT auth.uid() AS uid)))));

CREATE POLICY "task_referee_requests: select for owners and assigned referees" ON public.task_referee_requests
FOR SELECT
USING (((task_id IN (SELECT tasks.id
   FROM public.tasks
  WHERE (tasks.tasker_id = (SELECT auth.uid() AS uid)))) OR (matched_referee_id = (SELECT auth.uid() AS uid))));

CREATE POLICY "task_referee_requests: update for assigned referees" ON public.task_referee_requests
FOR UPDATE
USING ((matched_referee_id = (SELECT auth.uid() AS uid)))
WITH CHECK ((matched_referee_id = (SELECT auth.uid() AS uid)));
