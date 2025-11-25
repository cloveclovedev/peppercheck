-- Enqueue failed billing jobs for retry via pg_cron.
CREATE OR REPLACE FUNCTION public.retry_failed_billing_jobs()
RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
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
$$;

COMMENT ON FUNCTION public.retry_failed_billing_jobs() IS 'Enqueues failed billing_jobs (under retry limit) to the billing-worker Edge Function.';
