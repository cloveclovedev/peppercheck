CREATE TRIGGER on_payout_topup_config_update_set_updated_at
    BEFORE UPDATE ON public.payout_topup_config
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
