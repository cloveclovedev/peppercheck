CREATE OR REPLACE TRIGGER on_task_referee_requests_update_set_updated_at
BEFORE UPDATE ON public.task_referee_requests
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
