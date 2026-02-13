drop view if exists "public"."judgements_view";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_active_referee_tasks()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'task', to_jsonb(t),
        'judgement', CASE WHEN j.id IS NOT NULL THEN
          jsonb_build_object(
            'id', j.id,
            'comment', j.comment,
            'status', j.status,
            'created_at', j.created_at,
            'updated_at', j.updated_at,
            'is_confirmed', j.is_confirmed,
            'reopen_count', j.reopen_count,
            'is_evidence_timeout_confirmed', j.is_evidence_timeout_confirmed,
            'can_reopen', (
              j.status = 'rejected'
              AND j.reopen_count < 1
              AND t.due_date > now()
              AND EXISTS (
                SELECT 1 FROM public.task_evidences te
                WHERE te.task_id = trr.task_id
                  AND te.updated_at > j.updated_at
              )
            )
          )
        ELSE NULL END,
        'tasker_profile', to_jsonb(p)
      )
    ),
    '[]'::jsonb
  )
  FROM
    public.task_referee_requests AS trr
  INNER JOIN
    public.tasks AS t ON trr.task_id = t.id
  LEFT JOIN
    public.judgements AS j ON trr.id = j.id
  INNER JOIN
    public.profiles AS p ON t.tasker_id = p.id
  WHERE
    trr.matched_referee_id = auth.uid()
    AND trr.status IN ('matched', 'accepted');
$function$
;

CREATE OR REPLACE FUNCTION public.reopen_judgement(p_judgement_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_task_id uuid;
  v_can_reopen boolean;
BEGIN
  -- Get judgement details and can_reopen status via direct JOINs
  SELECT trr.task_id,
         (j.status = 'rejected'
          AND j.reopen_count < 1
          AND t.due_date > now()
          AND EXISTS (
            SELECT 1 FROM public.task_evidences te
            WHERE te.task_id = trr.task_id
              AND te.updated_at > j.updated_at
          ))
  INTO v_task_id, v_can_reopen
  FROM public.judgements j
  JOIN public.task_referee_requests trr ON j.id = trr.id
  JOIN public.tasks t ON trr.task_id = t.id
  WHERE j.id = p_judgement_id;

  -- Check if judgement exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Judgement not found';
  END IF;

  -- Security check: Only tasker can reopen their judgement
  IF NOT public.is_task_tasker(v_task_id, (SELECT auth.uid())) THEN
    RAISE EXCEPTION 'Only the task owner can request judgement reopening';
  END IF;

  -- Validation: can_reopen check (status=rejected, reopen_count<1, not past due, evidence updated)
  IF NOT v_can_reopen THEN
    RAISE EXCEPTION 'Judgement cannot be reopened. Check: status must be rejected, reopen count < 1, task not past due date, and evidence updated after judgement.';
  END IF;

  -- All validations passed - reopen the judgement
  UPDATE public.judgements
  SET
    status = 'awaiting_evidence',
    reopen_count = reopen_count + 1
  WHERE id = p_judgement_id;

END;
$function$
;


