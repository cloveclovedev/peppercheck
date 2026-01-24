CREATE OR REPLACE TRIGGER on_judgements_evidence_timeout_close_referee_request
AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmation();

COMMENT ON TRIGGER on_judgements_evidence_timeout_close_referee_request ON public.judgements IS 'Trigger that closes the specific task_referee_request when evidence timeout is confirmed by referee';
