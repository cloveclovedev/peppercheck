set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);

  INSERT INTO public.user_ratings (user_id)
  VALUES (NEW.id);

  -- Create point wallet with default balance (0)
  INSERT INTO public.point_wallets (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$function$
;


