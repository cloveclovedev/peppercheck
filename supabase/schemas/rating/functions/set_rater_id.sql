CREATE OR REPLACE FUNCTION public.set_rater_id() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
  -- Only set rater_id if it's not already provided
  IF NEW.rater_id IS NULL THEN
    NEW.rater_id := (select auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.set_rater_id() OWNER TO postgres;
