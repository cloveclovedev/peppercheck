-- Functions to claim billing jobs and invoke the billing-worker Edge Function

-- Claims a pending billing_job atomically and marks it processing while incrementing attempt_count.
CREATE OR REPLACE FUNCTION public.claim_billing_job(p_job_id uuid)
RETURNS SETOF public.billing_jobs
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
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
$$;

COMMENT ON FUNCTION public.claim_billing_job(uuid) IS 'Atomically claims a pending billing_job for processing and increments attempt_count.';


-- Trigger function: posts the new billing_job to the billing-worker Edge Function.
CREATE OR REPLACE FUNCTION public.call_billing_worker() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path = ''
AS $$
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
$$;

COMMENT ON FUNCTION public.call_billing_worker() IS 'Trigger hook that sends pending billing_job id to the billing-worker Edge Function via pg_net.';
