-- View: judgements_view
-- Replaces judgements_ext. Provides task_id, referee_id via JOINs.

CREATE OR REPLACE VIEW public.judgements_view AS
 SELECT 
    j.id,
    -- Restore task_id and referee_id from relationship
    trr.task_id,
    trr.matched_referee_id AS referee_id,
    
    j.comment,
    j.status,
    j.created_at,
    j.updated_at,
    j.is_confirmed,
    j.reopen_count,
    j.is_evidence_timeout_confirmed,
    
    -- can_reopen Logic
    ((j.status = 'rejected') AND (j.reopen_count < 1) AND (t.due_date > now()) AND (EXISTS ( SELECT 1
           FROM public.task_evidences te
          WHERE ((te.task_id = trr.task_id) AND (te.updated_at > j.updated_at))))) AS can_reopen

   FROM public.judgements j
     JOIN public.task_referee_requests trr ON j.id = trr.id
     JOIN public.tasks t ON trr.task_id = t.id;

COMMENT ON VIEW public.judgements_view IS 'View providing full judgement details including foreign Task and Referee IDs, plus can_reopen calculation.';
