-- Extensions required by the application
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
-- HTTP client for server-side callbacks
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA net;
-- Secret management for Postgres-side access to Supabase secrets
CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;
