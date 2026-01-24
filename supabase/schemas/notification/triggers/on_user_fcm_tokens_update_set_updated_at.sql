CREATE OR REPLACE TRIGGER on_user_fcm_tokens_update_set_updated_at
BEFORE UPDATE ON public.user_fcm_tokens
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
