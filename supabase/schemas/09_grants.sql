
-- Restrict billing_prices: no public grants (functions run as SECURITY DEFINER)
REVOKE ALL ON public.billing_prices FROM anon;
REVOKE ALL ON public.billing_prices FROM authenticated;
REVOKE ALL ON public.billing_prices FROM service_role;
