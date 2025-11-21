-- Functions grouped in 001_util_updated_at.sql
CREATE OR REPLACE FUNCTION public.handle_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_updated_at() OWNER TO postgres;

