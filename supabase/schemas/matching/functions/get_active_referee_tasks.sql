CREATE OR REPLACE FUNCTION public.get_active_referee_tasks() RETURNS jsonb
    LANGUAGE sql
    SET search_path = ''
    AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'task', to_jsonb(t), -- Single task object
        'judgement', to_jsonb(j), -- judgement information with can_reopen
        'tasker_profile', to_jsonb(p) -- Full tasker profile
      )
    ),
    '[]'::jsonb
  )
  FROM
    public.task_referee_requests AS trr
  INNER JOIN
    public.tasks AS t ON trr.task_id = t.id
  LEFT JOIN
    public.judgements_view AS j ON trr.id = j.id -- Use view and join by ID
  INNER JOIN
    public.profiles AS p ON t.tasker_id = p.id
  WHERE
    trr.matched_referee_id = auth.uid()
    AND trr.status IN ('matched', 'accepted');
$$;

ALTER FUNCTION public.get_active_referee_tasks() OWNER TO postgres;
