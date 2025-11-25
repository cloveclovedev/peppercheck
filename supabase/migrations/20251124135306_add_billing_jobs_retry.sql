create extension if not exists "pg_cron" with schema "pg_catalog";


  create table "public"."billing_settings" (
    "id" smallint not null default 1,
    "max_retry_attempts" integer not null default 3,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


CREATE UNIQUE INDEX billing_settings_pkey ON public.billing_settings USING btree (id);

alter table "public"."billing_settings" add constraint "billing_settings_pkey" PRIMARY KEY using index "billing_settings_pkey";

alter table "public"."billing_settings" add constraint "billing_settings_singleton" CHECK ((id = 1)) not valid;

alter table "public"."billing_settings" validate constraint "billing_settings_singleton";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.retry_failed_billing_jobs()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_url text;
  v_service_role_key text;
  v_headers jsonb;
  v_payload jsonb;
  v_max_attempts integer;
  v_limit integer := 50;
  v_count integer := 0;
  r record;
BEGIN
  SELECT decrypted_secret
    INTO v_url
    FROM vault.decrypted_secrets
   WHERE name = 'billing_worker_url';

  SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
   WHERE name = 'service_role_key';

  IF v_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'retry_failed_billing_jobs: missing secret (url:%, service_role_key:%)', v_url IS NULL, v_service_role_key IS NULL;
    RETURN;
  END IF;

  SELECT max_retry_attempts
    INTO v_max_attempts
    FROM public.billing_settings
   WHERE id = 1;

  IF v_max_attempts IS NULL THEN
    RAISE EXCEPTION 'retry_failed_billing_jobs: billing_settings not found or max_retry_attempts is null';
  END IF;

  v_headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || v_service_role_key,
    'apikey', v_service_role_key
  );

  FOR r IN
    SELECT id
      FROM public.billing_jobs
     WHERE status = 'failed'
       AND attempt_count < v_max_attempts
     ORDER BY updated_at ASC
     LIMIT v_limit
     FOR UPDATE SKIP LOCKED
  LOOP
    v_payload := jsonb_build_object('id', r.id);

    PERFORM net.http_post(
      url => v_url,
      body => v_payload,
      headers => v_headers,
      timeout_milliseconds => 8000
    );

    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'retry_failed_billing_jobs: enqueued % jobs', v_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_billing_job(p_job_id uuid)
 RETURNS SETOF public.billing_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_max_attempts integer;
BEGIN
  SELECT max_retry_attempts
    INTO v_max_attempts
    FROM public.billing_settings
   WHERE id = 1;

  IF v_max_attempts IS NULL THEN
    RAISE EXCEPTION 'claim_billing_job: billing_settings not found or max_retry_attempts is null';
  END IF;

  RETURN QUERY
    UPDATE public.billing_jobs
       SET status = 'processing',
           attempt_count = attempt_count + 1,
           updated_at = now()
     WHERE id = p_job_id
       AND status IN ('pending', 'failed')
       AND attempt_count < v_max_attempts
    RETURNING *;
END;
$function$
;

grant delete on table "public"."billing_settings" to "service_role";

grant insert on table "public"."billing_settings" to "service_role";

grant references on table "public"."billing_settings" to "service_role";

grant select on table "public"."billing_settings" to "service_role";

grant trigger on table "public"."billing_settings" to "service_role";

grant truncate on table "public"."billing_settings" to "service_role";

grant update on table "public"."billing_settings" to "service_role";

CREATE TRIGGER set_billing_settings_updated_at BEFORE UPDATE ON public.billing_settings FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


