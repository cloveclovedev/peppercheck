-- Functions
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_initial_grant integer;
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);

  INSERT INTO public.notification_settings (user_id) VALUES (NEW.id);

  INSERT INTO public.user_ratings (user_id)
  VALUES (NEW.id);

  INSERT INTO public.point_wallets (user_id)
  VALUES (NEW.id);

  -- Create trial point wallet with initial grant from config
  SELECT initial_grant_amount INTO v_initial_grant
  FROM public.trial_point_config
  WHERE id = true;

  v_initial_grant := COALESCE(v_initial_grant, 0);

  IF v_initial_grant > 0 THEN
    INSERT INTO public.trial_point_wallets (user_id, balance)
    VALUES (NEW.id, v_initial_grant);

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description)
    VALUES (NEW.id, v_initial_grant, 'initial_grant'::public.trial_point_reason, 'Trial points granted on registration');
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
