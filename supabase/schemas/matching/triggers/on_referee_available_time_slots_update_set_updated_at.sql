CREATE OR REPLACE TRIGGER on_referee_available_time_slots_update_set_updated_at
BEFORE UPDATE ON public.referee_available_time_slots
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
