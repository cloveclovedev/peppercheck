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
