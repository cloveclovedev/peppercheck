CREATE OR REPLACE TRIGGER on_referee_blocked_dates_update_set_updated_at
    BEFORE UPDATE ON public.referee_blocked_dates
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
