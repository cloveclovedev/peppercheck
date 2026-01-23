-- Functions grouped in 007_api_helpers.sql
CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path = ''
    AS $$
DECLARE
    v_task_id uuid;
BEGIN
  -- Get task_id from trr
  SELECT task_id INTO v_task_id 
  FROM public.task_referee_requests 
  WHERE id = NEW.id;

  -- Concurrency protection: lock the task row to prevent race conditions
  PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;
  
  -- Check if all judgements for this task are confirmed
  -- We need to check all requests that are 'accepted' or have a judgement
  IF NOT EXISTS (
    SELECT 1 FROM public.judgements j
    JOIN public.task_referee_requests trr ON j.id = trr.id
    WHERE trr.task_id = v_task_id AND j.is_confirmed = FALSE
  ) THEN
    UPDATE public.tasks SET status = 'closed' WHERE id = v_task_id;
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
    public.judgements_view AS j ON trr.id = j.id -- Use view and join by ID
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
DECLARE
    v_request RECORD;
BEGIN
  -- Only execute when is_confirmed changes from FALSE to TRUE
  IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
    
    -- Get request details for billing
    SELECT * INTO v_request
    FROM public.task_referee_requests
    WHERE id = NEW.id;

    -- Trigger billing (function handles non-billable cases by closing)
    PERFORM public.start_billing(v_request.id);
      
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
  FROM public.judgements_view
  WHERE id = p_judgement_id;

  -- Check if judgement exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Judgement not found';
  END IF;

  -- Security check: Only tasker can reopen their judgement
  IF NOT public.is_task_tasker(v_task_id, (SELECT auth.uid())) THEN
    RAISE EXCEPTION 'Only the task owner can request judgement reopening';
  END IF;

  -- Validation: Use the can_reopen logic from judgements_view view
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
$$;

ALTER FUNCTION public.reopen_judgement(p_judgement_id uuid) OWNER TO postgres;
