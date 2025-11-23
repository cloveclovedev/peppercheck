create type "public"."payout_job_status" as enum ('pending', 'processing', 'succeeded', 'failed');


  create table "public"."payout_jobs" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "status" public.payout_job_status not null default 'pending'::public.payout_job_status,
    "currency_code" text not null,
    "amount_minor" bigint not null,
    "payment_provider" text not null default 'stripe'::text,
    "provider_payout_id" text,
    "attempt_count" integer not null default 0,
    "last_error_code" text,
    "last_error_message" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."payout_jobs" enable row level security;

CREATE INDEX idx_payout_jobs_currency_code ON public.payout_jobs USING btree (currency_code);

CREATE INDEX idx_payout_jobs_provider_payout_id ON public.payout_jobs USING btree (provider_payout_id);

CREATE INDEX idx_payout_jobs_status ON public.payout_jobs USING btree (status);

CREATE INDEX idx_payout_jobs_user_id ON public.payout_jobs USING btree (user_id);

CREATE UNIQUE INDEX payout_jobs_pkey ON public.payout_jobs USING btree (id);

CREATE UNIQUE INDEX payout_jobs_provider_payout_id_key ON public.payout_jobs USING btree (provider_payout_id);

alter table "public"."payout_jobs" add constraint "payout_jobs_pkey" PRIMARY KEY using index "payout_jobs_pkey";

alter table "public"."payout_jobs" add constraint "payout_jobs_amount_minor_check" CHECK ((amount_minor >= 0)) not valid;

alter table "public"."payout_jobs" validate constraint "payout_jobs_amount_minor_check";

alter table "public"."payout_jobs" add constraint "payout_jobs_currency_code_fkey" FOREIGN KEY (currency_code) REFERENCES public.currencies(code) not valid;

alter table "public"."payout_jobs" validate constraint "payout_jobs_currency_code_fkey";

alter table "public"."payout_jobs" add constraint "payout_jobs_provider_payout_id_key" UNIQUE using index "payout_jobs_provider_payout_id_key";

alter table "public"."payout_jobs" add constraint "payout_jobs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) not valid;

alter table "public"."payout_jobs" validate constraint "payout_jobs_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.call_payout_worker()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_url text;
  v_service_role_key text;
  v_headers jsonb;
  v_payload jsonb;
BEGIN
  IF NEW.status <> 'pending' THEN
    RETURN NEW;
  END IF;

  SELECT decrypted_secret
    INTO v_url
    FROM vault.decrypted_secrets
   WHERE name = 'payout_worker_url';

  SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
   WHERE name = 'service_role_key';

  IF v_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'payout_worker trigger: missing secret (url:%, service_role_key:%)', v_url IS NULL, v_service_role_key IS NULL;
    RETURN NEW;
  END IF;

  v_headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || v_service_role_key,
    'apikey', v_service_role_key
  );
  v_payload := jsonb_build_object('id', NEW.id);

  -- Send via pg_net with explicit named args and jsonb body.
  PERFORM net.http_post(
    url => v_url,
    body => v_payload,
    headers => v_headers,
    timeout_milliseconds => 8000
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_payout_job(p_job_id uuid)
 RETURNS SETOF public.payout_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
    UPDATE public.payout_jobs
       SET status = 'processing',
           attempt_count = attempt_count + 1,
           updated_at = now()
     WHERE id = p_job_id
       AND status = 'pending'
    RETURNING *;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.finalize_payout_job(p_job_id uuid, p_provider_payout_id text, p_status public.payout_job_status, p_currency_code text DEFAULT NULL::text, p_amount_minor bigint DEFAULT NULL::bigint, p_error_code text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_job public.payout_jobs%ROWTYPE;
BEGIN
    IF p_status NOT IN ('succeeded', 'failed') THEN
        RAISE EXCEPTION 'Unsupported status: %', p_status;
    END IF;

    SELECT *
      INTO v_job
      FROM public.payout_jobs
     WHERE (p_job_id IS NOT NULL AND id = p_job_id)
        OR (provider_payout_id = p_provider_payout_id)
     LIMIT 1
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'finalize_payout_job: payout_job not found (job_id: %, provider_payout_id: %)', p_job_id, p_provider_payout_id;
        RETURN;
    END IF;

    UPDATE public.payout_jobs
       SET status = p_status,
           provider_payout_id = COALESCE(v_job.provider_payout_id, p_provider_payout_id),
           currency_code = COALESCE(p_currency_code, v_job.currency_code),
           amount_minor = COALESCE(p_amount_minor, v_job.amount_minor),
           last_error_code = CASE WHEN p_status = 'failed' THEN p_error_code ELSE NULL END,
           last_error_message = CASE WHEN p_status = 'failed' THEN p_error_message ELSE NULL END,
           updated_at = now()
     WHERE id = v_job.id;
END;
$function$
;

grant delete on table "public"."payout_jobs" to "anon";

grant insert on table "public"."payout_jobs" to "anon";

grant references on table "public"."payout_jobs" to "anon";

grant select on table "public"."payout_jobs" to "anon";

grant trigger on table "public"."payout_jobs" to "anon";

grant truncate on table "public"."payout_jobs" to "anon";

grant update on table "public"."payout_jobs" to "anon";

grant delete on table "public"."payout_jobs" to "authenticated";

grant insert on table "public"."payout_jobs" to "authenticated";

grant references on table "public"."payout_jobs" to "authenticated";

grant select on table "public"."payout_jobs" to "authenticated";

grant trigger on table "public"."payout_jobs" to "authenticated";

grant truncate on table "public"."payout_jobs" to "authenticated";

grant update on table "public"."payout_jobs" to "authenticated";

grant delete on table "public"."payout_jobs" to "service_role";

grant insert on table "public"."payout_jobs" to "service_role";

grant references on table "public"."payout_jobs" to "service_role";

grant select on table "public"."payout_jobs" to "service_role";

grant trigger on table "public"."payout_jobs" to "service_role";

grant truncate on table "public"."payout_jobs" to "service_role";

grant update on table "public"."payout_jobs" to "service_role";


  create policy "payout_jobs: insert if self"
  on "public"."payout_jobs"
  as permissive
  for insert
  to public
with check ((user_id = ( SELECT auth.uid() AS uid)));



  create policy "payout_jobs: select if self"
  on "public"."payout_jobs"
  as permissive
  for select
  to public
using ((user_id = ( SELECT auth.uid() AS uid)));


CREATE TRIGGER set_payout_jobs_updated_at BEFORE UPDATE ON public.payout_jobs FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trigger_call_payout_worker AFTER INSERT ON public.payout_jobs FOR EACH ROW WHEN ((new.status = 'pending'::public.payout_job_status)) EXECUTE FUNCTION public.call_payout_worker();


