-- Verifies the Phase 3a schema constraints in isolation: profiles username is
-- unique and length-checked (2..20), profiles/settings/fcm-tokens cascade from
-- users, and device_push_tokens is unique on token. Transactional and self-cleaning
-- (matches db/tests/test_identity_constraints.sql).
BEGIN;

-- profiles: username unique + length 2..20, id FK cascade from users.
DO $$
DECLARE u1 uuid; u2 uuid;
BEGIN
  INSERT INTO public.users DEFAULT VALUES RETURNING id INTO u1;
  INSERT INTO public.users DEFAULT VALUES RETURNING id INTO u2;
  INSERT INTO public.profiles (id, username) VALUES (u1, 'alice');

  -- duplicate username rejected
  BEGIN
    INSERT INTO public.profiles (id, username) VALUES (u2, 'alice');
    ASSERT false, 'duplicate username was allowed';
  EXCEPTION WHEN unique_violation THEN NULL; END;

  -- length < 2 rejected
  BEGIN
    INSERT INTO public.profiles (id, username) VALUES (u2, 'a');
    ASSERT false, 'short username was allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;

  -- length > 20 rejected
  BEGIN
    INSERT INTO public.profiles (id, username) VALUES (u2, 'abcdefghijklmnopqrstuvwxyz');
    ASSERT false, 'long username was allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;

  -- FK cascade: deleting the user removes the profile
  DELETE FROM public.users WHERE id = u1;
  ASSERT NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = u1), 'profile not cascaded';
END $$;

-- notification_settings: PK/FK cascade from users, defaults populate.
DO $$
DECLARE u uuid;
BEGIN
  INSERT INTO public.users DEFAULT VALUES RETURNING id INTO u;
  INSERT INTO public.notification_settings (user_id) VALUES (u);
  ASSERT (SELECT evidence_reminder_minutes FROM public.notification_settings WHERE user_id = u) = '{10}',
    'evidence_reminder_minutes default not applied';
  DELETE FROM public.users WHERE id = u;
  ASSERT NOT EXISTS (SELECT 1 FROM public.notification_settings WHERE user_id = u),
    'notification_settings not cascaded';
END $$;

-- device_push_tokens: token unique + FK cascade from users.
DO $$
DECLARE u uuid;
BEGIN
  INSERT INTO public.users DEFAULT VALUES RETURNING id INTO u;
  INSERT INTO public.device_push_tokens (user_id, token) VALUES (u, 'tok-1');

  BEGIN
    INSERT INTO public.device_push_tokens (user_id, token) VALUES (u, 'tok-1');
    ASSERT false, 'duplicate token was allowed';
  EXCEPTION WHEN unique_violation THEN NULL; END;

  DELETE FROM public.users WHERE id = u;
  ASSERT NOT EXISTS (SELECT 1 FROM public.device_push_tokens WHERE user_id = u),
    'device_push_tokens not cascaded';
END $$;

ROLLBACK;
