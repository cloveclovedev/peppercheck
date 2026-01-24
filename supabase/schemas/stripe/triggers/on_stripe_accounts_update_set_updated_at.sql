CREATE OR REPLACE TRIGGER on_stripe_accounts_update_set_updated_at
BEFORE UPDATE ON public.stripe_accounts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
