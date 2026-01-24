drop view if exists "public"."judgements_view";

set check_function_bodies = off;

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
        
        -- Previously triggered billing logic here:
        -- PERFORM public.start_billing(trr.id) ...
        -- Billing system has been removed. 
        -- Task closure is handled by close_task_if_all_judgements_confirmed trigger if needed.
        
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
DECLARE
    v_request RECORD;
BEGIN
  -- Only execute when is_confirmed changes from FALSE to TRUE
  IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
    
    -- Get request details for billing (legacy comment, kept for context)
    SELECT * INTO v_request
    FROM public.task_referee_requests
    WHERE id = NEW.id;

    -- Previously Triggered billing:
    -- PERFORM public.start_billing(v_request.id);
    -- Billing system has been removed. Logic handles confirmation state only now.
      
  END IF;

  RETURN NEW;
END;
$function$
;

create or replace view "public"."judgements_view" as  SELECT j.id,
    trr.task_id,
    trr.matched_referee_id AS referee_id,
    j.comment,
    j.status,
    j.created_at,
    j.updated_at,
    j.is_confirmed,
    j.reopen_count,
    j.is_evidence_timeout_confirmed,
    ((j.status = 'rejected'::public.judgement_status) AND (j.reopen_count < 1) AND (t.due_date > now()) AND (EXISTS ( SELECT 1
           FROM public.task_evidences te
          WHERE ((te.task_id = trr.task_id) AND (te.updated_at > j.updated_at))))) AS can_reopen
   FROM ((public.judgements j
     JOIN public.task_referee_requests trr ON ((j.id = trr.id)))
     JOIN public.tasks t ON ((trr.task_id = t.id)));



