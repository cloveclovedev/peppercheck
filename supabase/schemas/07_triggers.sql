-- Triggers

-- judgements ------------------------------------------------------
CREATE OR REPLACE TRIGGER on_judgements_update
BEFORE UPDATE ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER auto_score_timeout_referee_trigger
AFTER UPDATE ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.auto_score_timeout_referee();

CREATE OR REPLACE TRIGGER on_judgement_confirmed
AFTER UPDATE ON public.judgements
FOR EACH ROW
WHEN ((old.is_confirmed IS DISTINCT FROM new.is_confirmed))
EXECUTE FUNCTION public.handle_judgement_confirmation();

CREATE OR REPLACE TRIGGER trigger_auto_close_task
AFTER UPDATE ON public.judgements
FOR EACH ROW
WHEN ((new.is_confirmed = true) AND (old.is_confirmed = false))
EXECUTE FUNCTION public.close_task_if_all_judgements_confirmed();

CREATE OR REPLACE TRIGGER trigger_evidence_timeout_confirmation
AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmation();

COMMENT ON TRIGGER trigger_evidence_timeout_confirmation ON public.judgements IS 'Trigger that closes the specific task_referee_request when evidence timeout is confirmed by referee';

-- judgement_threads -----------------------------------------------
CREATE OR REPLACE TRIGGER on_judgement_threads_update
BEFORE UPDATE ON public.judgement_threads
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- tasks -----------------------------------------------------------
CREATE OR REPLACE TRIGGER on_tasks_update
BEFORE UPDATE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Block task creation when unpaid billing exists
CREATE OR REPLACE TRIGGER block_task_creation_if_unpaid
BEFORE INSERT ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.block_task_creation_if_unpaid();

-- task_evidences --------------------------------------------------
CREATE OR REPLACE TRIGGER validate_evidence_due_date_insert
BEFORE INSERT ON public.task_evidences
FOR EACH ROW EXECUTE FUNCTION public.validate_evidence_due_date();

CREATE OR REPLACE TRIGGER validate_evidence_due_date_update
BEFORE UPDATE OF description, status ON public.task_evidences
FOR EACH ROW EXECUTE FUNCTION public.validate_evidence_due_date();

CREATE OR REPLACE TRIGGER set_task_evidences_updated_at
BEFORE UPDATE ON public.task_evidences
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- task_referee_requests -------------------------------------------
CREATE OR REPLACE TRIGGER set_task_referee_requests_updated_at
BEFORE UPDATE ON public.task_referee_requests
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER task_referee_requests_matching_trigger
AFTER INSERT OR UPDATE ON public.task_referee_requests
FOR EACH ROW EXECUTE FUNCTION public.trigger_process_matching();

-- referee_available_time_slots ------------------------------------
CREATE OR REPLACE TRIGGER set_referee_available_time_slots_updated_at
BEFORE UPDATE ON public.referee_available_time_slots
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- profiles --------------------------------------------------------
CREATE OR REPLACE TRIGGER on_profiles_update
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- rating_histories ------------------------------------------------
CREATE OR REPLACE TRIGGER trigger_set_rater_id
BEFORE INSERT ON public.rating_histories
FOR EACH ROW EXECUTE FUNCTION public.set_rater_id();

CREATE OR REPLACE TRIGGER trigger_update_user_ratings
AFTER INSERT OR DELETE OR UPDATE ON public.rating_histories
FOR EACH ROW EXECUTE FUNCTION public.update_user_ratings();

-- user_ratings ----------------------------------------------------
CREATE OR REPLACE TRIGGER set_user_ratings_updated_at
BEFORE UPDATE ON public.user_ratings
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- stripe_accounts -------------------------------------------------
CREATE OR REPLACE TRIGGER set_stripe_accounts_updated_at
BEFORE UPDATE ON public.stripe_accounts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- billing_settings -------------------------------------------------
CREATE OR REPLACE TRIGGER set_billing_settings_updated_at
BEFORE UPDATE ON public.billing_settings
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- billing_jobs ----------------------------------------------------
CREATE OR REPLACE TRIGGER set_billing_jobs_updated_at
BEFORE UPDATE ON public.billing_jobs
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trigger_call_billing_worker
AFTER INSERT ON public.billing_jobs
FOR EACH ROW
WHEN (NEW.status = 'pending')
EXECUTE FUNCTION public.call_billing_worker();

-- payout_jobs ----------------------------------------------------
CREATE OR REPLACE TRIGGER set_payout_jobs_updated_at
BEFORE UPDATE ON public.payout_jobs
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trigger_call_payout_worker
AFTER INSERT ON public.payout_jobs
FOR EACH ROW
WHEN (NEW.status = 'pending')
EXECUTE FUNCTION public.call_payout_worker();

-- auth.users ------------------------------------------------------
CREATE OR REPLACE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
