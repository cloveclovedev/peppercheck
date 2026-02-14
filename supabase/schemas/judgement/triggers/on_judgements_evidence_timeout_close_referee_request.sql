CREATE OR REPLACE TRIGGER on_judgements_evidence_timeout_confirmed
AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmed();

COMMENT ON TRIGGER on_judgements_evidence_timeout_confirmed ON public.judgements IS 'Trigger that fires when evidence timeout is confirmed by referee';
