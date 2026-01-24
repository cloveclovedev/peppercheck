CREATE OR REPLACE TRIGGER on_judgements_update_set_updated_at
BEFORE UPDATE ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
