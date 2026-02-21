CREATE TRIGGER on_reward_exchange_rates_update_set_updated_at
    BEFORE UPDATE ON public.reward_exchange_rates
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
