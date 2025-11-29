-- Manually enqueue failed billing jobs for a user (defaults to auth.uid), allowing force_retry beyond max attempts.
CREATE OR REPLACE FUNCTION public.force_retry_failed_billing_jobs(p_user_id uuid DEFAULT NULL)
RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_target_user_id uuid;
  v_url text;
  v_service_role_key text;
  v_headers jsonb;
  v_payload jsonb;
  v_limit integer := 50;
  v_count integer := 0;
  r record;
BEGIN
  v_uid := auth.uid();
  v_target_user_id := COALESCE(p_user_id, v_uid);

  IF current_user <> 'service_role' AND v_target_user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not authorized';
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
    RAISE EXCEPTION 'force_retry_failed_billing_jobs: missing secret';
  END IF;

  v_headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || v_service_role_key,
    'apikey', v_service_role_key
  );

  FOR r IN
    SELECT bj.id, bj.attempt_count
      FROM public.billing_jobs bj
      JOIN public.task_referee_requests trr ON trr.id = bj.referee_request_id
      JOIN public.tasks t ON t.id = trr.task_id
     WHERE t.tasker_id = v_target_user_id
       AND bj.status = 'failed'
     ORDER BY bj.updated_at ASC
     LIMIT v_limit
     FOR UPDATE SKIP LOCKED
  LOOP
    v_payload := jsonb_build_object('id', r.id, 'force_retry', true);

    PERFORM net.http_post(
      url => v_url,
      body => v_payload,
      headers => v_headers,
      timeout_milliseconds => 8000
    );

    v_count := v_count + 1;
    RAISE LOG 'force_retry_failed_billing_jobs enqueued job % (attempt_count=%)', r.id, r.attempt_count;
  END LOOP;

  RAISE NOTICE 'force_retry_failed_billing_jobs: enqueued % jobs for user %', v_count, v_target_user_id;
END;
$$;

COMMENT ON FUNCTION public.force_retry_failed_billing_jobs(uuid)
  IS 'Allows a user (or service_role) to enqueue failed billing jobs for retry (force_retry=true).';
