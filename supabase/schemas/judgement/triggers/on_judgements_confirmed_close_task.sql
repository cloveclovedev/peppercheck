CREATE OR REPLACE TRIGGER on_judgements_confirmed_close_task
AFTER UPDATE ON public.judgements
FOR EACH ROW
WHEN ((new.is_confirmed = true) AND (old.is_confirmed = false))
EXECUTE FUNCTION public.close_task_if_all_judgements_confirmed();
