-- Verifies the identity schema constraints in isolation: user_identities is
-- unique on (issuer, subject), and deleting a user cascades to its identities.
-- Transactional and self-cleaning (matches db/tests/test_role_separation.sql).
BEGIN;

WITH u AS (INSERT INTO public.users DEFAULT VALUES RETURNING id)
INSERT INTO public.user_identities (user_id, issuer, subject)
SELECT id, 'iss', 'sub-1' FROM u;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.user_identities (user_id, issuer, subject)
    SELECT id, 'iss', 'sub-1' FROM public.users LIMIT 1;
    RAISE EXCEPTION 'duplicate (issuer, subject) should violate the unique constraint';
  EXCEPTION
    WHEN unique_violation THEN NULL; -- expected
  END;
END $$;

DELETE FROM public.users;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.user_identities) = 0,
    'deleting a user must cascade-delete its user_identities';
END $$;

-- email/email_verified columns + the lower(email) lookup index exist
-- (Phase 3b account-deletion request matching).
DO $$
BEGIN
  ASSERT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_identities' AND column_name = 'email'
  ), 'user_identities.email column must exist';
  ASSERT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_identities' AND column_name = 'email_verified'
  ), 'user_identities.email_verified column must exist';
  ASSERT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'user_identities'
      AND indexdef ILIKE '%lower(email)%'
  ), 'a lower(email) index on user_identities must exist';
END $$;

ROLLBACK;
