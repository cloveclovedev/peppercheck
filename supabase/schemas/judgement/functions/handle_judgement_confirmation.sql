CREATE OR REPLACE FUNCTION public.handle_judgement_confirmation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_request RECORD;
BEGIN
  -- Only execute when is_confirmed changes from FALSE to TRUE
  IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
    
    -- Get request details for billing (legacy comment, kept for context)
    SELECT * INTO v_request
    FROM public.task_referee_requests
    WHERE id = NEW.id;

    -- Previously Triggered billing:
    -- PERFORM public.start_billing(v_request.id);
    -- Billing system has been removed. Logic handles confirmation state only now.
      
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_judgement_confirmation() OWNER TO postgres;
