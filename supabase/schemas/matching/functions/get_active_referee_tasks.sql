CREATE OR REPLACE FUNCTION public.get_active_referee_tasks() RETURNS jsonb
    LANGUAGE sql
    SET search_path = ''
    AS $$
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
$$;

ALTER FUNCTION public.get_active_referee_tasks() OWNER TO postgres;
