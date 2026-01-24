CREATE OR REPLACE TRIGGER on_task_evidences_update_set_updated_at
BEFORE UPDATE ON public.task_evidences
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
