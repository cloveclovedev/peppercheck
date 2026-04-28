-- DML, not detected by schema diff
-- Backfill username for existing rows where username IS NULL
DO $$
DECLARE
  r RECORD;
  v_username TEXT;
  v_attempts INT;
BEGIN
  FOR r IN SELECT id FROM public.profiles WHERE username IS NULL LOOP
    v_attempts := 0;
    LOOP
      v_username := 'user_' || encode(extensions.gen_random_bytes(4), 'hex');
      BEGIN
        UPDATE public.profiles SET username = v_username WHERE id = r.id;
        EXIT;
      EXCEPTION WHEN unique_violation THEN
        v_attempts := v_attempts + 1;
        IF v_attempts >= 5 THEN
          RAISE EXCEPTION 'Could not generate unique username for user % after % attempts', r.id, v_attempts;
        END IF;
      END;
    END LOOP;
  END LOOP;
END $$;

alter table "public"."profiles" alter column "username" set not null;

alter table "public"."profiles" add constraint "profiles_username_length_check" CHECK (((char_length(username) >= 2) AND (char_length(username) <= 20))) not valid;

alter table "public"."profiles" validate constraint "profiles_username_length_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_initial_grant integer;
  v_username TEXT;
  v_attempts INT := 0;
BEGIN
  -- Generate a unique username with retry on collision
  LOOP
    v_username := 'user_' || encode(extensions.gen_random_bytes(4), 'hex');
    BEGIN
      INSERT INTO public.profiles (id, username) VALUES (NEW.id, v_username);
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_attempts := v_attempts + 1;
      IF v_attempts >= 5 THEN
        RAISE EXCEPTION 'Could not generate unique username after % attempts', v_attempts;
      END IF;
    END;
  END LOOP;

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
$function$
;


