-- Functions to claim payout jobs, call payout-worker, and finalize payout results.

-- Claims a pending payout_job atomically and marks it processing while incrementing attempt_count.
CREATE OR REPLACE FUNCTION public.claim_payout_job(p_job_id uuid)
RETURNS SETOF public.payout_jobs
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
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
$$;

COMMENT ON FUNCTION public.claim_payout_job(uuid) IS 'Atomically claims a pending payout_job for processing and increments attempt_count.';


-- Trigger function: posts the new payout_job to the payout-worker Edge Function.
CREATE OR REPLACE FUNCTION public.call_payout_worker() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path = ''
AS $$
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
$$;

COMMENT ON FUNCTION public.call_payout_worker() IS 'Trigger hook that sends pending payout_job id to the payout-worker Edge Function via database webhooks (supabase_functions.http_request).';


-- Finalize payout job based on provider webhook or worker result.
-- Atomically updates payout_jobs status and stores provider_payout_id/error info.
CREATE OR REPLACE FUNCTION public.finalize_payout_job(
    p_job_id uuid,
    p_provider_payout_id text,
    p_status public.payout_job_status,
    p_currency_code text DEFAULT NULL,
    p_amount_minor bigint DEFAULT NULL,
    p_error_code text DEFAULT NULL,
    p_error_message text DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
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
$$;

COMMENT ON FUNCTION public.finalize_payout_job(uuid, text, public.payout_job_status, text, bigint, text, text)
  IS 'Finalizes payout_jobs from provider webhook or worker result.';
