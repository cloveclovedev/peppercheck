CREATE OR REPLACE TRIGGER on_judgement_confirmed
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = false))
    EXECUTE FUNCTION public.handle_judgement_confirmed();
