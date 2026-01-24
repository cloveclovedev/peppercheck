CREATE OR REPLACE TRIGGER on_point_wallets_update_set_updated_at
BEFORE UPDATE ON public.point_wallets
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
