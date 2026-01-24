CREATE OR REPLACE TRIGGER on_judgements_timeout_score_referee
AFTER UPDATE ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.auto_score_timeout_referee();
