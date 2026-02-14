CREATE TRIGGER on_reward_wallets_update_set_updated_at
    BEFORE UPDATE ON public.reward_wallets
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
