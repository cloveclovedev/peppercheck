create type "public"."billing_job_status" as enum ('pending', 'processing', 'succeeded', 'failed');


  create table "public"."billing_jobs" (
    "id" uuid not null default gen_random_uuid(),
    "referee_request_id" uuid not null,
    "status" public.billing_job_status not null default 'pending'::public.billing_job_status,
    "currency_code" text not null,
    "amount_minor" bigint not null,
    "payment_provider" text not null default 'stripe'::text,
    "provider_payment_id" text,
    "attempt_count" integer not null default 0,
    "last_error_code" text,
    "last_error_message" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."billing_jobs" enable row level security;


  create table "public"."currencies" (
    "code" text not null,
    "kind" text not null,
    "exponent" integer not null,
    "description" text
      );


CREATE UNIQUE INDEX billing_jobs_pkey ON public.billing_jobs USING btree (id);

CREATE UNIQUE INDEX billing_jobs_provider_payment_id_key ON public.billing_jobs USING btree (provider_payment_id);

CREATE UNIQUE INDEX billing_jobs_referee_request_id_key ON public.billing_jobs USING btree (referee_request_id);

CREATE UNIQUE INDEX currencies_pkey ON public.currencies USING btree (code);

CREATE INDEX idx_billing_jobs_currency_code ON public.billing_jobs USING btree (currency_code);

CREATE INDEX idx_billing_jobs_provider_payment_id ON public.billing_jobs USING btree (provider_payment_id);

CREATE INDEX idx_billing_jobs_referee_request_id ON public.billing_jobs USING btree (referee_request_id);

CREATE INDEX idx_billing_jobs_status ON public.billing_jobs USING btree (status);

alter table "public"."billing_jobs" add constraint "billing_jobs_pkey" PRIMARY KEY using index "billing_jobs_pkey";

alter table "public"."currencies" add constraint "currencies_pkey" PRIMARY KEY using index "currencies_pkey";

alter table "public"."billing_jobs" add constraint "billing_jobs_amount_minor_check" CHECK ((amount_minor >= 0)) not valid;

alter table "public"."billing_jobs" validate constraint "billing_jobs_amount_minor_check";

alter table "public"."billing_jobs" add constraint "billing_jobs_currency_code_fkey" FOREIGN KEY (currency_code) REFERENCES public.currencies(code) not valid;

alter table "public"."billing_jobs" validate constraint "billing_jobs_currency_code_fkey";

alter table "public"."billing_jobs" add constraint "billing_jobs_provider_payment_id_key" UNIQUE using index "billing_jobs_provider_payment_id_key";

alter table "public"."billing_jobs" add constraint "billing_jobs_referee_request_id_fkey" FOREIGN KEY (referee_request_id) REFERENCES public.task_referee_requests(id) not valid;

alter table "public"."billing_jobs" validate constraint "billing_jobs_referee_request_id_fkey";

alter table "public"."billing_jobs" add constraint "billing_jobs_referee_request_id_key" UNIQUE using index "billing_jobs_referee_request_id_key";

alter table "public"."currencies" add constraint "currencies_exponent_check" CHECK (((exponent >= 0) AND (exponent <= 18))) not valid;

alter table "public"."currencies" validate constraint "currencies_exponent_check";

alter table "public"."currencies" add constraint "currencies_kind_check" CHECK ((kind = ANY (ARRAY['fiat'::text, 'crypto'::text]))) not valid;

alter table "public"."currencies" validate constraint "currencies_kind_check";

grant delete on table "public"."billing_jobs" to "anon";

grant insert on table "public"."billing_jobs" to "anon";

grant references on table "public"."billing_jobs" to "anon";

grant select on table "public"."billing_jobs" to "anon";

grant trigger on table "public"."billing_jobs" to "anon";

grant truncate on table "public"."billing_jobs" to "anon";

grant update on table "public"."billing_jobs" to "anon";

grant delete on table "public"."billing_jobs" to "authenticated";

grant insert on table "public"."billing_jobs" to "authenticated";

grant references on table "public"."billing_jobs" to "authenticated";

grant select on table "public"."billing_jobs" to "authenticated";

grant trigger on table "public"."billing_jobs" to "authenticated";

grant truncate on table "public"."billing_jobs" to "authenticated";

grant update on table "public"."billing_jobs" to "authenticated";

grant delete on table "public"."billing_jobs" to "service_role";

grant insert on table "public"."billing_jobs" to "service_role";

grant references on table "public"."billing_jobs" to "service_role";

grant select on table "public"."billing_jobs" to "service_role";

grant trigger on table "public"."billing_jobs" to "service_role";

grant truncate on table "public"."billing_jobs" to "service_role";

grant update on table "public"."billing_jobs" to "service_role";

grant delete on table "public"."currencies" to "anon";

grant insert on table "public"."currencies" to "anon";

grant references on table "public"."currencies" to "anon";

grant select on table "public"."currencies" to "anon";

grant trigger on table "public"."currencies" to "anon";

grant truncate on table "public"."currencies" to "anon";

grant update on table "public"."currencies" to "anon";

grant delete on table "public"."currencies" to "authenticated";

grant insert on table "public"."currencies" to "authenticated";

grant references on table "public"."currencies" to "authenticated";

grant select on table "public"."currencies" to "authenticated";

grant trigger on table "public"."currencies" to "authenticated";

grant truncate on table "public"."currencies" to "authenticated";

grant update on table "public"."currencies" to "authenticated";

grant delete on table "public"."currencies" to "service_role";

grant insert on table "public"."currencies" to "service_role";

grant references on table "public"."currencies" to "service_role";

grant select on table "public"."currencies" to "service_role";

grant trigger on table "public"."currencies" to "service_role";

grant truncate on table "public"."currencies" to "service_role";

grant update on table "public"."currencies" to "service_role";


  create policy "billing_jobs: select if referee"
  on "public"."billing_jobs"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.task_referee_requests trr
  WHERE ((trr.id = billing_jobs.referee_request_id) AND (trr.matched_referee_id = ( SELECT auth.uid() AS uid))))));



  create policy "billing_jobs: select if tasker"
  on "public"."billing_jobs"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM (public.task_referee_requests trr
     JOIN public.tasks t ON ((t.id = trr.task_id)))
  WHERE ((trr.id = billing_jobs.referee_request_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))));


CREATE TRIGGER set_billing_jobs_updated_at BEFORE UPDATE ON public.billing_jobs FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


