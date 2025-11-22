-- Finalize billing job based on Stripe PaymentIntent webhook.
-- Atomically updates billing_jobs status and optionally closes the related referee request.
CREATE OR REPLACE FUNCTION public.finalize_billing_job(
    p_job_id uuid,
    p_payment_intent_id text,
    p_status public.billing_job_status,
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
    v_job public.billing_jobs%ROWTYPE;
BEGIN
    IF p_status NOT IN ('succeeded', 'failed') THEN
        RAISE EXCEPTION 'Unsupported status: %', p_status;
    END IF;

    SELECT *
      INTO v_job
      FROM public.billing_jobs
     WHERE (p_job_id IS NOT NULL AND id = p_job_id)
        OR (provider_payment_id = p_payment_intent_id)
     LIMIT 1
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'finalize_billing_job: billing_job not found (job_id: %, payment_intent: %)', p_job_id, p_payment_intent_id;
        RETURN;
    END IF;

    UPDATE public.billing_jobs
       SET status = p_status,
           provider_payment_id = COALESCE(v_job.provider_payment_id, p_payment_intent_id),
           currency_code = COALESCE(p_currency_code, v_job.currency_code),
           amount_minor = COALESCE(p_amount_minor, v_job.amount_minor),
           last_error_code = CASE WHEN p_status = 'failed' THEN p_error_code ELSE NULL END,
           last_error_message = CASE WHEN p_status = 'failed' THEN p_error_message ELSE NULL END,
           updated_at = now()
     WHERE id = v_job.id;

    IF p_status = 'succeeded' THEN
        UPDATE public.task_referee_requests
           SET status = 'closed',
               updated_at = now()
         WHERE id = v_job.referee_request_id
           AND status = 'payment_processing';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.finalize_billing_job(uuid, text, public.billing_job_status, text, bigint, text, text)
  IS 'Finalizes billing_jobs from Stripe webhook and closes referee request when payment succeeds.';
