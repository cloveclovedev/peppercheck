
-- Keep anon/authenticated fully revoked; allow service_role to read prices for billing-worker
REVOKE ALL ON public.billing_prices FROM anon;
REVOKE ALL ON public.billing_prices FROM authenticated;
GRANT SELECT ON public.billing_prices TO service_role;
