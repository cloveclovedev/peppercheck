-- Local Secrets Setup for Supabase Vault
-- Run this script via Dashboard SQL Editor or `supabase db execute --file supabase/snippets/setup_secrets.sql`

-- 1. send_notification_url
-- For Mac/Windows Docker users, use 'host.docker.internal' to reach the host machine.
-- This URL points to the locally running 'send-notification' Edge Function.
SELECT vault.create_secret(
  'http://host.docker.internal:54321/functions/v1/send-notification', 
  'send_notification_url', 
  'URL for send-notification Edge Function (Local)'
);

-- 2. supabase_url
-- IMPORTANT: Replace '<YOUR_SUPABASE_URL>' with your actual Supabase project URL.
-- For local development, this is typically 'http://127.0.0.1:54321'.
SELECT vault.create_secret(
    '<YOUR_SUPABASE_URL>',
    'supabase_url'
);

-- 3. service_role_key
-- IMPORTANT: Replace 'SERVICE_ROLE_KEY_HERE' with your actual local service role key.
-- You can find this key by running `supabase status` in your terminal.
SELECT vault.create_secret(
  'SERVICE_ROLE_KEY_HERE', 
  'service_role_key', 
  'Service role key for internal API calls'
);
