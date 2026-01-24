ALTER TABLE public.judgements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Judgements: insert if referee" ON public.judgements
FOR INSERT
WITH CHECK ((EXISTS (
    SELECT 1 FROM public.task_referee_requests trr
    WHERE trr.id = judgements.id
      AND trr.matched_referee_id = (SELECT auth.uid())
)));

CREATE POLICY "Judgements: select if tasker or referee" ON public.judgements
FOR SELECT
USING ((EXISTS (
    SELECT 1 FROM public.task_referee_requests trr
    LEFT JOIN public.tasks t ON trr.task_id = t.id
    WHERE trr.id = judgements.id
      AND (
           trr.matched_referee_id = (SELECT auth.uid()) 
           OR 
           t.tasker_id = (SELECT auth.uid())
      )
)));

CREATE POLICY "Judgements: update if referee or tasker" ON public.judgements
FOR UPDATE
USING ((EXISTS (
    SELECT 1 FROM public.task_referee_requests trr
    LEFT JOIN public.tasks t ON trr.task_id = t.id
    WHERE trr.id = judgements.id
      AND (
           trr.matched_referee_id = (SELECT auth.uid()) 
           OR 
           t.tasker_id = (SELECT auth.uid())
      )
)));
