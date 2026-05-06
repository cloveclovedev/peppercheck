ALTER TABLE public.payout_topup_config ENABLE ROW LEVEL SECURITY;

-- No SELECT/INSERT/UPDATE/DELETE policies are defined for any client role.
-- Only service_role (used by the operator Edge Function) bypasses RLS.
-- Authenticated clients are blocked by RLS default-deny.
