CREATE OR REPLACE TRIGGER on_task_evidences_update_validate_due_date
BEFORE UPDATE OF description, status ON public.task_evidences
FOR EACH ROW EXECUTE FUNCTION public.validate_evidence_due_date();
