CREATE OR REPLACE TRIGGER on_judgement_threads_update_set_updated_at
BEFORE UPDATE ON public.judgement_threads
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
