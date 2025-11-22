-- Initiates billing for a referee request if eligible (approved/rejected confirmed, or evidence_timeout confirmed). Idempotent via ON CONFLICT on billing_jobs. judgement_timeout is intentionally excluded.
CREATE OR REPLACE FUNCTION public.start_billing(p_referee_request_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_trr public.task_referee_requests%ROWTYPE;
    v_judgement public.judgements%ROWTYPE;
    v_currency text := 'JPY'; -- TODO: tie to request/task when multi-currency is introduced
    v_amount bigint;
BEGIN
    -- Lock target referee request
    SELECT * INTO v_trr
    FROM public.task_referee_requests
    WHERE id = p_referee_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'start_billing: referee_request % not found', p_referee_request_id;
        RETURN;
    END IF;

    -- If already in payment_processing, assume billing in flight
    IF v_trr.status = 'payment_processing' THEN
        RETURN;
    END IF;

    -- Find associated judgement (prefer explicit FK, fallback to task/referee combo for backward compatibility)
    SELECT * INTO v_judgement
      FROM public.judgements
     WHERE referee_request_id = v_trr.id
     LIMIT 1;

    IF NOT FOUND THEN
      SELECT * INTO v_judgement
        FROM public.judgements
       WHERE task_id = v_trr.task_id
         AND referee_id = v_trr.matched_referee_id
       LIMIT 1;
    END IF;

    IF NOT FOUND THEN
        RAISE NOTICE 'start_billing: no judgement found for referee_request %', v_trr.id;
        RETURN;
    END IF;

    -- Eligibility: confirmed approved/rejected OR confirmed evidence_timeout
    IF ((v_judgement.status IN ('approved','rejected') AND v_judgement.is_confirmed = TRUE)
        OR (v_judgement.status = 'evidence_timeout' AND v_judgement.is_evidence_timeout_confirmed = TRUE)) THEN

        SELECT amount_minor INTO v_amount
          FROM public.billing_prices
         WHERE currency_code = v_currency
           AND matching_strategy = v_trr.matching_strategy;

        IF v_amount IS NULL THEN
            RAISE EXCEPTION 'Billing price not configured for currency % and strategy %', v_currency, v_trr.matching_strategy;
        END IF;

        INSERT INTO public.billing_jobs (
            referee_request_id,
            status,
            currency_code,
            amount_minor,
            payment_provider,
            attempt_count
        ) VALUES (
            v_trr.id,
            'pending',
            v_currency,
            v_amount,
            'stripe',
            0
        ) ON CONFLICT (referee_request_id) DO NOTHING;

        UPDATE public.task_referee_requests
           SET status = 'payment_processing',
               updated_at = now()
         WHERE id = v_trr.id;

    ELSE
        -- Not billable: close the request if not already closed
        UPDATE public.task_referee_requests
           SET status = 'closed',
               updated_at = now()
         WHERE id = v_trr.id
           AND status <> 'closed';
    END IF;

    RETURN;
END;
$$;

ALTER FUNCTION public.start_billing(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.start_billing(uuid) IS 'Idempotent billing trigger: decides eligibility, inserts billing_jobs, and moves task_referee_requests to payment_processing or closed.';
