CREATE OR REPLACE TRIGGER on_rating_histories_insert_set_rater_id
BEFORE INSERT ON public.rating_histories
FOR EACH ROW EXECUTE FUNCTION public.set_rater_id();
