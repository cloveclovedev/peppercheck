-- Functions grouped in 007_api_helpers.sql
CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path = ''
    AS $$
BEGIN
  -- Concurrency protection: lock the task row to prevent race conditions
  PERFORM * FROM public.tasks WHERE id = NEW.task_id FOR UPDATE;
  
  -- Check if all judgements for this task are confirmed
  IF NOT EXISTS (
    SELECT 1 FROM public.judgements 
    WHERE task_id = NEW.task_id AND is_confirmed = FALSE
  ) THEN
    UPDATE public.tasks SET status = 'closed' WHERE id = NEW.task_id;
  END IF;
  
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.close_task_if_all_judgements_confirmed() OWNER TO postgres;

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
    public.judgements_ext AS j ON t.id = j.task_id AND trr.matched_referee_id = j.referee_id -- Changed to judgements_ext
  INNER JOIN
    public.profiles AS p ON t.tasker_id = p.id
  WHERE
    trr.matched_referee_id = auth.uid()
    AND trr.status IN ('matched', 'accepted');
$$;

ALTER FUNCTION public.get_active_referee_tasks() OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.handle_judgement_confirmation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
  -- Only execute when is_confirmed changes from FALSE to TRUE
  IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
    
    -- Trigger billing (function handles non-billable cases by closing)
    PERFORM public.start_billing(trr.id)
    FROM public.task_referee_requests trr
    WHERE trr.task_id = NEW.task_id
      AND trr.matched_referee_id = NEW.referee_id
    LIMIT 1;
      
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_judgement_confirmation() OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.reopen_judgement(p_judgement_id uuid) RETURNS void
    LANGUAGE plpgsql
    SET search_path = ''
    AS $$
DECLARE
  v_task_id uuid;
  v_can_reopen boolean;
BEGIN
  -- Get judgement details and can_reopen status from the view
  SELECT task_id, can_reopen
  INTO v_task_id, v_can_reopen
  FROM public.judgements_ext
  WHERE id = p_judgement_id;

  -- Check if judgement exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Judgement not found';
  END IF;

  -- Security check: Only tasker can reopen their judgement
  IF NOT public.is_task_tasker(v_task_id, (SELECT auth.uid())) THEN
    RAISE EXCEPTION 'Only the task owner can request judgement reopening';
  END IF;

  -- Validation: Use the can_reopen logic from judgements_ext view
  IF NOT v_can_reopen THEN
    RAISE EXCEPTION 'Judgement cannot be reopened. Check: status must be rejected, reopen count < 1, task not past due date, and evidence updated after judgement.';
  END IF;

  -- All validations passed - reopen the judgement
  UPDATE public.judgements 
  SET 
    status = 'open',
    reopen_count = reopen_count + 1
  WHERE id = p_judgement_id;

END;
$$;

ALTER FUNCTION public.reopen_judgement(p_judgement_id uuid) OWNER TO postgres;
