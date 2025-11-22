revoke delete on table "public"."billing_prices" from "anon";

revoke insert on table "public"."billing_prices" from "anon";

revoke references on table "public"."billing_prices" from "anon";

revoke select on table "public"."billing_prices" from "anon";

revoke trigger on table "public"."billing_prices" from "anon";

revoke truncate on table "public"."billing_prices" from "anon";

revoke update on table "public"."billing_prices" from "anon";

revoke delete on table "public"."billing_prices" from "authenticated";

revoke insert on table "public"."billing_prices" from "authenticated";

revoke references on table "public"."billing_prices" from "authenticated";

revoke select on table "public"."billing_prices" from "authenticated";

revoke trigger on table "public"."billing_prices" from "authenticated";

revoke truncate on table "public"."billing_prices" from "authenticated";

revoke update on table "public"."billing_prices" from "authenticated";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.call_billing_worker()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_url text;
  v_service_role_key text;
  v_payload text;
BEGIN
  IF NEW.status <> 'pending' THEN
    RETURN NEW;
  END IF;

  SELECT decrypted_secret
    INTO v_url
    FROM vault.decrypted_secrets
   WHERE name = 'billing_worker_url';

  SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
   WHERE name = 'service_role_key';

  IF v_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'billing_worker trigger: missing secret (url:%, service_role_key:%)', v_url IS NULL, v_service_role_key IS NULL;
    RETURN NEW;
  END IF;

  v_payload := jsonb_build_object('id', NEW.id)::text;

  PERFORM net.http_post(
    url => v_url,
    headers => jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body => v_payload,
    timeout_milliseconds => 8000
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_billing_job(p_job_id uuid)
 RETURNS SETOF public.billing_jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
    UPDATE public.billing_jobs
       SET status = 'processing',
           attempt_count = attempt_count + 1,
           updated_at = now()
     WHERE id = p_job_id
       AND status = 'pending'
    RETURNING *;
END;
$function$
;

CREATE TRIGGER trigger_call_billing_worker AFTER INSERT ON public.billing_jobs FOR EACH ROW WHEN ((new.status = 'pending'::public.billing_job_status)) EXECUTE FUNCTION public.call_billing_worker();


