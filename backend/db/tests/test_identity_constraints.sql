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

ROLLBACK;
