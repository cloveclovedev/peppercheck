CREATE TRIGGER on_reward_payouts_update_set_updated_at
    BEFORE UPDATE ON public.reward_payouts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
