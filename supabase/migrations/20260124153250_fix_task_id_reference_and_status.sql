drop view if exists "public"."judgements_view";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.auto_score_timeout_referee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement RECORD;
    v_task RECORD;
BEGIN
    -- Only process when is_confirmed changes from false to true
    IF TG_OP = 'UPDATE' AND OLD.is_confirmed = false AND NEW.is_confirmed = true THEN
        
        -- Get the judgement details with task info
        SELECT 
            j.id,
            trr.task_id,
            trr.matched_referee_id AS referee_id,
            j.status,
            t.tasker_id
        INTO v_judgement
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        WHERE j.id = NEW.id;

        -- If this is a judgement_timeout confirmation, automatically score referee as 0
        IF v_judgement.status = 'judgement_timeout' THEN
            -- Insert rating from tasker to referee (0 points for timeout)
            -- The existing trigger_update_user_ratings will automatically update user_ratings table
            INSERT INTO public.rating_histories (
                rater_id,        -- tasker who confirms timeout (evaluator)
                ratee_id,        -- referee who timed out (being evaluated)
                judgement_id,    -- specific judgement being rated
                task_id,         -- task reference
                rating_type,     -- 'referee' - evaluating referee performance
                rating,          -- 0 points for timeout penalty
                comment,         -- explanation for automatic rating
                created_at       -- timestamp
            ) VALUES (
                v_judgement.tasker_id,  -- tasker rates the referee
                v_judgement.referee_id, -- referee gets rated
                v_judgement.id,         -- specific judgement
                v_judgement.task_id,    -- task reference
                'referee',              -- rating type: referee being rated
                0,                      -- 0 points for timeout
                'Automatic 0-point rating due to referee timeout', -- explanation
                NOW()                   -- timestamp
            ) ON CONFLICT (rater_id, ratee_id, judgement_id) DO NOTHING; -- Prevent duplicate ratings

            -- Note: user_ratings table will be automatically updated by the existing 
            -- trigger_update_user_ratings trigger after this rating_histories INSERT
            
            RAISE NOTICE 'Auto-scored referee % with 0 points for timeout on judgement %', 
                v_judgement.referee_id, v_judgement.id;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_and_handle_evidence_timeouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_timeout_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have evidence timeout (due_date passed without evidence)
    -- Only update judgements that are still 'open' and past the due date with no evidence
    UPDATE public.judgements j
    SET 
        status = 'evidence_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    LEFT JOIN public.task_evidences te ON t.id = te.task_id
    WHERE j.id = trr.id
    AND j.status = 'awaiting_evidence' -- Changed from 'open' to 'awaiting_evidence' based on enum
    AND v_now > t.due_date
    AND te.id IS NULL; -- No evidence submitted

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'processed_at', v_now
        );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_and_handle_referee_timeouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_timeout_count INTEGER := 0;
    v_updated_judgements RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
    v_timeout_threshold TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have timed out (due_date + 3 hours)
    -- Only update judgements that are still 'open' and past the timeout threshold
    UPDATE public.judgements j
    SET 
        status = 'review_timeout',
        updated_at = v_now
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON trr.task_id = t.id
    WHERE j.id = trr.id
    AND j.status = 'in_review' -- Assuming 'open' meant 'in_review' (referee has evidence and needs to judge)
    AND v_now > (t.due_date + INTERVAL '3 hours');

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'processed_at', v_now
        );
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


CREATE OR REPLACE FUNCTION public.submit_evidence(p_task_id uuid, p_description text, p_assets jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_evidence_id UUID;
    v_asset JSONB;
    v_updated_count INTEGER;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    -- 1. Validation
    -- 1.1 Input Check
    IF p_description IS NULL OR trim(p_description) = '' THEN
        RAISE EXCEPTION 'Description is required';
    END IF;

    IF p_assets IS NULL OR jsonb_array_length(p_assets) = 0 THEN
        RAISE EXCEPTION 'At least one evidence asset is required';
    END IF;

    -- 1.2 Authorization & Status Check
    -- Check if:
    --   a) User is tasker (Auth check)
    --   b) Task/Judgement is in valid state:
    --      - Status is 'open' (Awaiting Evidence)
    --      - OR Status is 'rejected' AND reopen_count < 1 AND Now < DueDate
    -- Note: We join with tasks to check tasker_id and due_date
    IF NOT EXISTS (
        SELECT 1
        FROM public.tasks t
        JOIN public.task_referee_requests trr ON trr.task_id = t.id
        JOIN public.judgements j ON j.id = trr.id
        WHERE t.id = p_task_id
          AND t.tasker_id = auth.uid()
          AND (
              j.status IN ('awaiting_evidence', 'in_review')
              OR
              (j.status = 'rejected' AND j.reopen_count < 1 AND t.due_date > v_now)
          )
    ) THEN
        RAISE EXCEPTION 'Not authorized or task not in valid state for evidence submission';
    END IF;

    -- 2. Insert Evidence
    INSERT INTO public.task_evidences (
        task_id,
        description,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_task_id,
        p_description,
        'ready', -- Mark as ready since assets are uploaded
        v_now,
        v_now
    ) RETURNING id INTO v_evidence_id;

    -- 2.1 Insert Evidence Assets
    FOR v_asset IN SELECT * FROM jsonb_array_elements(p_assets)
    LOOP
        INSERT INTO public.task_evidence_assets (
            evidence_id,
            file_url,
            file_size_bytes,
            content_type,
            created_at,
            processing_status,
            public_url
        ) VALUES (
            v_evidence_id,
            v_asset->>'file_url',
            (v_asset->>'file_size_bytes')::BIGINT,
            v_asset->>'content_type',
            v_now,
            'completed',
            v_asset->>'public_url'
        );
    END LOOP;

    -- 3. Update Judgements
    -- Transition 'open' or 'rejected' to 'in_review'
    UPDATE public.judgements j
    SET 
        status = 'in_review',
        updated_at = v_now
    FROM public.task_referee_requests trr
    WHERE 
        j.id = trr.id
        AND trr.task_id = p_task_id
        AND (
            j.status IN ('awaiting_evidence', 'in_review')
            OR 
            (j.status = 'rejected' AND j.reopen_count < 1) 
        );

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'evidence_id', v_evidence_id,
        'updated_judgements_count', v_updated_count
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to submit evidence: %', SQLERRM;
END;
$function$
;


