alter table "public"."task_referee_requests" drop constraint "task_referee_requests_status_check";


  create table "public"."billing_prices" (
    "currency_code" text not null,
    "matching_strategy" text not null,
    "amount_minor" bigint not null
      );


alter table "public"."billing_prices" enable row level security;

alter table "public"."judgements" add column "referee_request_id" uuid;

CREATE UNIQUE INDEX billing_prices_pkey ON public.billing_prices USING btree (currency_code, matching_strategy);

CREATE INDEX idx_billing_prices_currency_code ON public.billing_prices USING btree (currency_code);

CREATE INDEX idx_billing_prices_matching_strategy ON public.billing_prices USING btree (matching_strategy);

CREATE INDEX idx_judgements_referee_request_id ON public.judgements USING btree (referee_request_id);

CREATE UNIQUE INDEX judgements_referee_request_id_key ON public.judgements USING btree (referee_request_id);

alter table "public"."billing_prices" add constraint "billing_prices_pkey" PRIMARY KEY using index "billing_prices_pkey";

alter table "public"."billing_prices" add constraint "billing_prices_amount_minor_check" CHECK ((amount_minor >= 0)) not valid;

alter table "public"."billing_prices" validate constraint "billing_prices_amount_minor_check";

alter table "public"."billing_prices" add constraint "billing_prices_currency_code_fkey" FOREIGN KEY (currency_code) REFERENCES public.currencies(code) not valid;

alter table "public"."billing_prices" validate constraint "billing_prices_currency_code_fkey";

alter table "public"."judgements" add constraint "judgements_referee_request_id_fkey" FOREIGN KEY (referee_request_id) REFERENCES public.task_referee_requests(id) not valid;

alter table "public"."judgements" validate constraint "judgements_referee_request_id_fkey";

alter table "public"."judgements" add constraint "judgements_referee_request_id_key" UNIQUE using index "judgements_referee_request_id_key";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'matched'::text, 'accepted'::text, 'declined'::text, 'expired'::text, 'payment_processing'::text, 'closed'::text]))) not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_status_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.start_billing(p_referee_request_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_task_id UUID;
    v_referee_id UUID;
    v_request_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Only proceed if is_evidence_timeout_confirmed was changed from false to true
    -- and the judgement status is evidence_timeout
    IF NEW.is_evidence_timeout_confirmed = true 
       AND OLD.is_evidence_timeout_confirmed = false 
       AND NEW.status = 'evidence_timeout' THEN
        
        -- Get the task_id and referee_id from the judgement
        v_task_id := NEW.task_id;
        v_referee_id := NEW.referee_id;
        
        -- Let billing logic decide processing/close
        PERFORM public.start_billing(trr.id)
        FROM public.task_referee_requests trr
        WHERE trr.task_id = v_task_id
          AND trr.matched_referee_id = v_referee_id
        LIMIT 1;
        
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the original update
        RAISE WARNING 'Error in handle_evidence_timeout_confirmation: %', SQLERRM;
        -- Return NEW to allow the original judgement update to succeed
        RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_judgement_confirmation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Only execute when is_confirmed changes from FALSE to TRUE
  IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
    
    -- Trigger billing (function handles non-billable cases by closing)
    PERFORM public.start_billing(trr.id)
    FROM public.task_referee_requests trr
    WHERE trr.task_id = NEW.task_id
      AND trr.matched_referee_id = NEW.referee_id
    LIMIT 1;
      
  END IF;

  RETURN NEW;
END;
$function$
;


