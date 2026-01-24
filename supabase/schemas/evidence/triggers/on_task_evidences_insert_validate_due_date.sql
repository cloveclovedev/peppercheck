CREATE OR REPLACE TRIGGER on_task_evidences_insert_validate_due_date
BEFORE INSERT ON public.task_evidences
FOR EACH ROW EXECUTE FUNCTION public.validate_evidence_due_date();
