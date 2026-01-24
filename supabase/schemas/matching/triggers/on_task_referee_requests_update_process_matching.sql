CREATE OR REPLACE TRIGGER on_task_referee_requests_update_process_matching
AFTER UPDATE ON public.task_referee_requests
FOR EACH ROW EXECUTE FUNCTION public.trigger_process_matching();
