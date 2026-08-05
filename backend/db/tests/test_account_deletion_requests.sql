-- Verifies the account_deletion_requests schema constraints in isolation:
-- one row per user (UNIQUE user_id), FK cascade from users, and the
-- guarded upsert (only WHERE status = 'unverified') that Store.Upsert relies
-- on so a third party who merely knows an email cannot revert a
-- Phase-6-confirmed request back to 'unverified'. Transactional and
-- self-cleaning (matches db/tests/test_identity_constraints.sql).
BEGIN;

DO $$
DECLARE u uuid;
BEGIN
  INSERT INTO public.users DEFAULT VALUES RETURNING id INTO u;
  INSERT INTO public.account_deletion_requests (user_id, claimed_email)
    VALUES (u, 'first@example.com');

  -- one row per user: a second plain insert for the same user_id is rejected.
  BEGIN
    INSERT INTO public.account_deletion_requests (user_id, claimed_email)
      VALUES (u, 'second@example.com');
    ASSERT false, 'duplicate user_id was allowed';
  EXCEPTION WHEN unique_violation THEN NULL; END;

  -- FK cascade: deleting the user removes the request.
  DELETE FROM public.users WHERE id = u;
  ASSERT NOT EXISTS (SELECT 1 FROM public.account_deletion_requests WHERE user_id = u),
    'account_deletion_requests row not cascaded';
END $$;

-- Status guard: the public form's upsert (Store.Upsert) must not revert a
-- Phase-6-confirmed request back to 'unverified'.
DO $$
DECLARE u uuid;
BEGIN
  INSERT INTO public.users DEFAULT VALUES RETURNING id INTO u;
  INSERT INTO public.account_deletion_requests (user_id, claimed_email)
    VALUES (u, 'original@example.com');
  UPDATE public.account_deletion_requests SET status = 'verified' WHERE user_id = u;

  -- The exact guarded upsert Store.Upsert issues.
  INSERT INTO public.account_deletion_requests (user_id, claimed_email)
    VALUES (u, 'attacker-supplied@example.com')
    ON CONFLICT (user_id) DO UPDATE
      SET claimed_email = EXCLUDED.claimed_email, updated_at = now()
      WHERE public.account_deletion_requests.status = 'unverified';

  ASSERT (SELECT status FROM public.account_deletion_requests WHERE user_id = u) = 'verified',
    'a verified request must not revert to unverified';
  ASSERT (SELECT claimed_email FROM public.account_deletion_requests WHERE user_id = u) = 'original@example.com',
    'a verified request''s claimed_email must not change via the public upsert';
END $$;

-- Repeated requests for one account collapse to a single 'unverified' row
-- (the upsert dedup path, status still 'unverified').
DO $$
DECLARE u uuid;
BEGIN
  INSERT INTO public.users DEFAULT VALUES RETURNING id INTO u;
  INSERT INTO public.account_deletion_requests (user_id, claimed_email)
    VALUES (u, 'first-attempt@example.com');

  INSERT INTO public.account_deletion_requests (user_id, claimed_email)
    VALUES (u, 'second-attempt@example.com')
    ON CONFLICT (user_id) DO UPDATE
      SET claimed_email = EXCLUDED.claimed_email, updated_at = now()
      WHERE public.account_deletion_requests.status = 'unverified';

  ASSERT (SELECT count(*) FROM public.account_deletion_requests WHERE user_id = u) = 1,
    'repeated requests must collapse to a single row';
  ASSERT (SELECT claimed_email FROM public.account_deletion_requests WHERE user_id = u) = 'second-attempt@example.com',
    'the unverified row must pick up the latest claimed_email';
END $$;

ROLLBACK;
