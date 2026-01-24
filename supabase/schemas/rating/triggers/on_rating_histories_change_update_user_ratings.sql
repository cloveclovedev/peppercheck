CREATE OR REPLACE TRIGGER on_rating_histories_change_update_user_ratings
AFTER INSERT OR DELETE OR UPDATE ON public.rating_histories
FOR EACH ROW EXECUTE FUNCTION public.update_user_ratings();
