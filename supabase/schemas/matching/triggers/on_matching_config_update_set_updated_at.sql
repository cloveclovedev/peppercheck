CREATE OR REPLACE TRIGGER on_matching_config_update_set_updated_at
BEFORE UPDATE ON public.matching_config
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
