CREATE OR REPLACE TRIGGER on_profiles_update_set_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
