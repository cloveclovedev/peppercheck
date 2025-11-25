
-- Keep anon/authenticated fully revoked; allow service_role to read prices for billing-worker
REVOKE ALL ON public.billing_prices FROM anon;
REVOKE ALL ON public.billing_prices FROM authenticated;
GRANT SELECT ON public.billing_prices TO service_role;

-- Billing settings are admin-only; no anon/authenticated access
REVOKE ALL ON public.billing_settings FROM anon;
REVOKE ALL ON public.billing_settings FROM authenticated;
GRANT SELECT, UPDATE ON public.billing_settings TO service_role;
