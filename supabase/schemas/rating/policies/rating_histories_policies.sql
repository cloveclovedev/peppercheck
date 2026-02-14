ALTER TABLE public.rating_histories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Rating Histories: insert if authenticated" ON public.rating_histories
FOR INSERT TO authenticated
WITH CHECK (true);

CREATE POLICY "Rating Histories: select if task participant" ON public.rating_histories
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.task_referee_requests trr
        JOIN public.tasks t ON t.id = trr.task_id
        WHERE trr.id = rating_histories.judgement_id
        AND (
            t.tasker_id = (SELECT auth.uid())
            OR trr.matched_referee_id = (SELECT auth.uid())
        )
    )
);
