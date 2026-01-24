drop trigger if exists "set_billing_jobs_updated_at" on "public"."billing_jobs";

drop trigger if exists "trigger_call_billing_worker" on "public"."billing_jobs";

drop trigger if exists "set_billing_settings_updated_at" on "public"."billing_settings";

drop trigger if exists "set_payout_jobs_updated_at" on "public"."payout_jobs";

drop trigger if exists "trigger_call_payout_worker" on "public"."payout_jobs";

drop trigger if exists "block_task_creation_if_unpaid" on "public"."tasks";

drop policy "billing_jobs: select if referee" on "public"."billing_jobs";

drop policy "billing_jobs: select if tasker" on "public"."billing_jobs";

drop policy "payout_jobs: insert if self" on "public"."payout_jobs";

drop policy "payout_jobs: select if self" on "public"."payout_jobs";

revoke delete on table "public"."billing_jobs" from "anon";

revoke insert on table "public"."billing_jobs" from "anon";

revoke references on table "public"."billing_jobs" from "anon";

revoke select on table "public"."billing_jobs" from "anon";

revoke trigger on table "public"."billing_jobs" from "anon";

revoke truncate on table "public"."billing_jobs" from "anon";

revoke update on table "public"."billing_jobs" from "anon";

revoke delete on table "public"."billing_jobs" from "authenticated";

revoke insert on table "public"."billing_jobs" from "authenticated";

revoke references on table "public"."billing_jobs" from "authenticated";

revoke select on table "public"."billing_jobs" from "authenticated";

revoke trigger on table "public"."billing_jobs" from "authenticated";

revoke truncate on table "public"."billing_jobs" from "authenticated";

revoke update on table "public"."billing_jobs" from "authenticated";

revoke delete on table "public"."billing_jobs" from "service_role";

revoke insert on table "public"."billing_jobs" from "service_role";

revoke references on table "public"."billing_jobs" from "service_role";

revoke select on table "public"."billing_jobs" from "service_role";

revoke trigger on table "public"."billing_jobs" from "service_role";

revoke truncate on table "public"."billing_jobs" from "service_role";

revoke update on table "public"."billing_jobs" from "service_role";

revoke delete on table "public"."billing_prices" from "service_role";

revoke insert on table "public"."billing_prices" from "service_role";

revoke references on table "public"."billing_prices" from "service_role";

revoke select on table "public"."billing_prices" from "service_role";

revoke trigger on table "public"."billing_prices" from "service_role";

revoke truncate on table "public"."billing_prices" from "service_role";

revoke update on table "public"."billing_prices" from "service_role";

revoke delete on table "public"."billing_settings" from "service_role";

revoke insert on table "public"."billing_settings" from "service_role";

revoke references on table "public"."billing_settings" from "service_role";

revoke select on table "public"."billing_settings" from "service_role";

revoke trigger on table "public"."billing_settings" from "service_role";

revoke truncate on table "public"."billing_settings" from "service_role";

revoke update on table "public"."billing_settings" from "service_role";

revoke delete on table "public"."payout_jobs" from "anon";

revoke insert on table "public"."payout_jobs" from "anon";

revoke references on table "public"."payout_jobs" from "anon";

revoke select on table "public"."payout_jobs" from "anon";

revoke trigger on table "public"."payout_jobs" from "anon";

revoke truncate on table "public"."payout_jobs" from "anon";

revoke update on table "public"."payout_jobs" from "anon";

revoke delete on table "public"."payout_jobs" from "authenticated";

revoke insert on table "public"."payout_jobs" from "authenticated";

revoke references on table "public"."payout_jobs" from "authenticated";

revoke select on table "public"."payout_jobs" from "authenticated";

revoke trigger on table "public"."payout_jobs" from "authenticated";

revoke truncate on table "public"."payout_jobs" from "authenticated";

revoke update on table "public"."payout_jobs" from "authenticated";

revoke delete on table "public"."payout_jobs" from "service_role";

revoke insert on table "public"."payout_jobs" from "service_role";

revoke references on table "public"."payout_jobs" from "service_role";

revoke select on table "public"."payout_jobs" from "service_role";

revoke trigger on table "public"."payout_jobs" from "service_role";

revoke truncate on table "public"."payout_jobs" from "service_role";

revoke update on table "public"."payout_jobs" from "service_role";

alter table "public"."billing_jobs" drop constraint "billing_jobs_amount_minor_check";

alter table "public"."billing_jobs" drop constraint "billing_jobs_currency_code_fkey";

alter table "public"."billing_jobs" drop constraint "billing_jobs_provider_payment_id_key";

alter table "public"."billing_jobs" drop constraint "billing_jobs_referee_request_id_fkey";

alter table "public"."billing_jobs" drop constraint "billing_jobs_referee_request_id_key";

alter table "public"."billing_prices" drop constraint "billing_prices_amount_minor_check";

alter table "public"."billing_prices" drop constraint "billing_prices_currency_code_fkey";

alter table "public"."billing_settings" drop constraint "billing_settings_singleton";

alter table "public"."payout_jobs" drop constraint "payout_jobs_amount_minor_check";

alter table "public"."payout_jobs" drop constraint "payout_jobs_currency_code_fkey";

alter table "public"."payout_jobs" drop constraint "payout_jobs_provider_payout_id_key";

alter table "public"."payout_jobs" drop constraint "payout_jobs_user_id_fkey";

drop function if exists "public"."block_task_creation_if_unpaid"();

drop function if exists "public"."call_billing_worker"();

drop function if exists "public"."call_payout_worker"();

drop function if exists "public"."claim_billing_job"(p_job_id uuid, p_force_retry boolean);

drop function if exists "public"."claim_payout_job"(p_job_id uuid);

drop function if exists "public"."finalize_billing_job"(p_job_id uuid, p_payment_intent_id text, p_status public.billing_job_status, p_currency_code text, p_amount_minor bigint, p_error_code text, p_error_message text);

drop function if exists "public"."finalize_payout_job"(p_job_id uuid, p_provider_payout_id text, p_status public.payout_job_status, p_currency_code text, p_amount_minor bigint, p_error_code text, p_error_message text);

drop function if exists "public"."force_retry_failed_billing_jobs"(p_user_id uuid);

drop function if exists "public"."is_billing_action_required"(p_user_id uuid);

drop function if exists "public"."retry_failed_billing_jobs"();

drop function if exists "public"."start_billing"(p_referee_request_id uuid);

drop view if exists "public"."judgements_view";

alter table "public"."billing_jobs" drop constraint "billing_jobs_pkey";

alter table "public"."billing_prices" drop constraint "billing_prices_pkey";

alter table "public"."billing_settings" drop constraint "billing_settings_pkey";

alter table "public"."payout_jobs" drop constraint "payout_jobs_pkey";

drop index if exists "public"."billing_jobs_pkey";

drop index if exists "public"."billing_jobs_provider_payment_id_key";

drop index if exists "public"."billing_jobs_referee_request_id_key";

drop index if exists "public"."billing_prices_pkey";

drop index if exists "public"."billing_settings_pkey";

drop index if exists "public"."idx_billing_jobs_currency_code";

drop index if exists "public"."idx_billing_jobs_provider_payment_id";

drop index if exists "public"."idx_billing_jobs_referee_request_id";

drop index if exists "public"."idx_billing_jobs_status";

drop index if exists "public"."idx_billing_prices_currency_code";

drop index if exists "public"."idx_billing_prices_matching_strategy";

drop index if exists "public"."idx_payout_jobs_currency_code";

drop index if exists "public"."idx_payout_jobs_provider_payout_id";

drop index if exists "public"."idx_payout_jobs_status";

drop index if exists "public"."idx_payout_jobs_user_id";

drop index if exists "public"."payout_jobs_pkey";

drop index if exists "public"."payout_jobs_provider_payout_id_key";

drop table "public"."billing_jobs";

drop table "public"."billing_prices";

drop table "public"."billing_settings";

drop table "public"."payout_jobs";

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



