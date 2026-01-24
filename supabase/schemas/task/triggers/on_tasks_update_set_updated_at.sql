CREATE OR REPLACE TRIGGER on_tasks_update_set_updated_at
BEFORE UPDATE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
