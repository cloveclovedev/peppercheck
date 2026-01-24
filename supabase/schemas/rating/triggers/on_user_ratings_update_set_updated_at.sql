CREATE OR REPLACE TRIGGER on_user_ratings_update_set_updated_at
BEFORE UPDATE ON public.user_ratings
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
