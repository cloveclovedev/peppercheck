-- Verifies the runtime grant model in isolation: a migrator-owned table grants
-- DML to the app role automatically, and the app role cannot run DDL. Runs as a
-- superuser inside a transaction and rolls back, so it needs no container init.
BEGIN;

CREATE ROLE test_migrator;
GRANT CREATE, USAGE ON SCHEMA public TO test_migrator;
CREATE ROLE test_app;
GRANT USAGE ON SCHEMA public TO test_app;
ALTER DEFAULT PRIVILEGES FOR ROLE test_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO test_app;

SET ROLE test_migrator;
CREATE TABLE public.role_probe (id int PRIMARY KEY, note text);
RESET ROLE;

-- App role can DML the migrator-owned table.
SET ROLE test_app;
INSERT INTO public.role_probe (id, note) VALUES (1, 'ok');
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.role_probe) = 1, 'app INSERT should succeed';
END $$;

-- App role must NOT be able to run DDL.
DO $$
BEGIN
  BEGIN
    EXECUTE 'CREATE TABLE public.should_not_exist (id int)';
    RAISE EXCEPTION 'app role must not be able to CREATE TABLE';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL; -- expected
  END;
END $$;
RESET ROLE;

ROLLBACK;
