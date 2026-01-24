drop trigger if exists "on_judgement_threads_update" on "public"."judgement_threads";

drop trigger if exists "auto_score_timeout_referee_trigger" on "public"."judgements";

drop trigger if exists "on_judgement_confirmed" on "public"."judgements";

drop trigger if exists "on_judgements_update" on "public"."judgements";

drop trigger if exists "trigger_auto_close_task" on "public"."judgements";

drop trigger if exists "trigger_evidence_timeout_confirmation" on "public"."judgements";

drop trigger if exists "on_profiles_update" on "public"."profiles";

drop trigger if exists "trigger_set_rater_id" on "public"."rating_histories";

drop trigger if exists "trigger_update_user_ratings" on "public"."rating_histories";

drop trigger if exists "set_referee_available_time_slots_updated_at" on "public"."referee_available_time_slots";

drop trigger if exists "set_stripe_accounts_updated_at" on "public"."stripe_accounts";

drop trigger if exists "set_task_evidences_updated_at" on "public"."task_evidences";

drop trigger if exists "validate_evidence_due_date_insert" on "public"."task_evidences";

drop trigger if exists "validate_evidence_due_date_update" on "public"."task_evidences";

drop trigger if exists "set_task_referee_requests_updated_at" on "public"."task_referee_requests";

drop trigger if exists "task_referee_requests_matching_trigger" on "public"."task_referee_requests";

drop trigger if exists "on_tasks_update" on "public"."tasks";

drop trigger if exists "set_user_ratings_updated_at" on "public"."user_ratings";

drop view if exists "public"."judgements_view";

create or replace view "public"."judgements_view" as  SELECT j.id,
    trr.task_id,
    trr.matched_referee_id AS referee_id,
    j.comment,
    j.status,
    j.created_at,
    j.updated_at,
    j.is_confirmed,
    j.reopen_count,
    j.is_evidence_timeout_confirmed,
    ((j.status = 'rejected'::public.judgement_status) AND (j.reopen_count < 1) AND (t.due_date > now()) AND (EXISTS ( SELECT 1
           FROM public.task_evidences te
          WHERE ((te.task_id = trr.task_id) AND (te.updated_at > j.updated_at))))) AS can_reopen
   FROM ((public.judgements j
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
     JOIN public.tasks t ON ((trr.task_id = t.id)));


CREATE TRIGGER on_judgement_threads_update_set_updated_at BEFORE UPDATE ON public.judgement_threads FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_judgements_confirmed_close_task AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.is_confirmed = true) AND (old.is_confirmed = false))) EXECUTE FUNCTION public.close_task_if_all_judgements_confirmed();

CREATE TRIGGER on_judgements_evidence_timeout_close_referee_request AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmation();

CREATE TRIGGER on_judgements_timeout_score_referee AFTER UPDATE ON public.judgements FOR EACH ROW EXECUTE FUNCTION public.auto_score_timeout_referee();

CREATE TRIGGER on_judgements_update_set_updated_at BEFORE UPDATE ON public.judgements FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_matching_config_update_set_updated_at BEFORE UPDATE ON public.matching_config FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_point_wallets_update_set_updated_at BEFORE UPDATE ON public.point_wallets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_profiles_update_set_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_rating_histories_change_update_user_ratings AFTER INSERT OR DELETE OR UPDATE ON public.rating_histories FOR EACH ROW EXECUTE FUNCTION public.update_user_ratings();

CREATE TRIGGER on_rating_histories_insert_set_rater_id BEFORE INSERT ON public.rating_histories FOR EACH ROW EXECUTE FUNCTION public.set_rater_id();

CREATE TRIGGER on_referee_available_time_slots_update_set_updated_at BEFORE UPDATE ON public.referee_available_time_slots FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_stripe_accounts_update_set_updated_at BEFORE UPDATE ON public.stripe_accounts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_task_evidences_insert_validate_due_date BEFORE INSERT ON public.task_evidences FOR EACH ROW EXECUTE FUNCTION public.validate_evidence_due_date();

CREATE TRIGGER on_task_evidences_update_set_updated_at BEFORE UPDATE ON public.task_evidences FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_task_evidences_update_validate_due_date BEFORE UPDATE OF description, status ON public.task_evidences FOR EACH ROW EXECUTE FUNCTION public.validate_evidence_due_date();

CREATE TRIGGER on_task_referee_requests_insert_process_matching AFTER INSERT ON public.task_referee_requests FOR EACH ROW EXECUTE FUNCTION public.trigger_process_matching();

CREATE TRIGGER on_task_referee_requests_update_process_matching AFTER UPDATE ON public.task_referee_requests FOR EACH ROW EXECUTE FUNCTION public.trigger_process_matching();

CREATE TRIGGER on_task_referee_requests_update_set_updated_at BEFORE UPDATE ON public.task_referee_requests FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_tasks_update_set_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_user_fcm_tokens_update_set_updated_at BEFORE UPDATE ON public.user_fcm_tokens FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_user_ratings_update_set_updated_at BEFORE UPDATE ON public.user_ratings FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_user_subscriptions_update_set_updated_at BEFORE UPDATE ON public.user_subscriptions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


