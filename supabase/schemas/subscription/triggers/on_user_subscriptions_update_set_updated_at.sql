CREATE OR REPLACE TRIGGER on_user_subscriptions_update_set_updated_at
BEFORE UPDATE ON public.user_subscriptions
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
