-- Functions grouped in 004_time_limits.sql
CREATE OR REPLACE FUNCTION public.auto_score_timeout_referee() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
    v_task RECORD;
BEGIN
    -- Only process when is_confirmed changes from false to true
    IF TG_OP = 'UPDATE' AND OLD.is_confirmed = false AND NEW.is_confirmed = true THEN
        
        -- Get the judgement details with task info
        SELECT 
            j.id,
            j.task_id,
            j.referee_id,
            j.status,
            t.tasker_id
        INTO v_judgement
        FROM public.judgements j
        INNER JOIN public.tasks t ON j.task_id = t.id
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
$$;

ALTER FUNCTION public.auto_score_timeout_referee() OWNER TO postgres;

COMMENT ON FUNCTION public.auto_score_timeout_referee() IS 'Corrected version: Automatically scores referee as 0 when a judgement_timeout is confirmed by the tasker. Only inserts into rating_histories - user_ratings table is updated automatically by existing trigger system. This maintains consistency with the existing rating architecture.';

CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout_from_referee(p_judgement_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement_record public.judgements%ROWTYPE;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Get judgement details and verify it exists and is in evidence_timeout status
    SELECT * INTO v_judgement_record
    FROM public.judgements 
    WHERE id = p_judgement_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;
    
    IF v_judgement_record.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement is not in evidence_timeout status';
    END IF;
    
    IF v_judgement_record.is_evidence_timeout_confirmed = true THEN
        RAISE EXCEPTION 'Evidence timeout already confirmed';
    END IF;
    
    -- Update judgement to mark evidence timeout as confirmed
    UPDATE public.judgements 
    SET 
        is_evidence_timeout_confirmed = true,
        updated_at = v_now
    WHERE id = p_judgement_id;
    
    RETURN json_build_object(
        'success', true,
        'judgement_id', p_judgement_id,
        'confirmed_at', v_now
    );

END;
$$;

ALTER FUNCTION public.confirm_evidence_timeout_from_referee(p_judgement_id uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_evidence_timeout_from_referee(p_judgement_id uuid) IS 'Allows referee to confirm evidence timeout by setting is_evidence_timeout_confirmed to true. Returns JSON on success, raises exception on error. Triggers system processes to close the task_referee_request.';

CREATE OR REPLACE FUNCTION public.detect_and_handle_evidence_timeouts() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_timeout_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have evidence timeout (due_date passed without evidence)
    -- Only update judgements that are still 'open' and past the due date with no evidence
    UPDATE public.judgements 
    SET 
        status = 'evidence_timeout',
        updated_at = v_now
    FROM public.tasks t
    LEFT JOIN public.task_evidences te ON t.id = te.task_id
    WHERE public.judgements.task_id = t.id
    AND public.judgements.status = 'open'
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
$$;

ALTER FUNCTION public.detect_and_handle_evidence_timeouts() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_and_handle_evidence_timeouts() IS 'Detects evidence timeouts (due_date passed without evidence submission) and updates judgement status to evidence_timeout. Should be called periodically by a cron job or scheduler.';

CREATE OR REPLACE FUNCTION public.detect_and_handle_referee_timeouts() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_timeout_count INTEGER := 0;
    v_updated_judgements RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
    v_timeout_threshold TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have timed out (due_date + 3 hours)
    -- Only update judgements that are still 'open' and past the timeout threshold
    UPDATE public.judgements 
    SET 
        status = 'judgement_timeout',
        updated_at = v_now
    FROM public.tasks t
    WHERE public.judgements.task_id = t.id
    AND public.judgements.status = 'open'
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
$$;

ALTER FUNCTION public.detect_and_handle_referee_timeouts() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_and_handle_referee_timeouts() IS 'Detects referee timeouts (due_date + 3 hours) and updates judgement status to judgement_timeout. Should be called periodically by a cron job or scheduler.';

CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
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
$$;

ALTER FUNCTION public.handle_evidence_timeout_confirmation() OWNER TO postgres;

COMMENT ON FUNCTION public.handle_evidence_timeout_confirmation() IS 'Automatically closes the specific task_referee_request (matched to the referee) when referee confirms evidence timeout by setting is_evidence_timeout_confirmed to true';

CREATE OR REPLACE FUNCTION public.validate_evidence_due_date() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_due_date TIMESTAMP WITH TIME ZONE;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Get task due_date
    SELECT t.due_date INTO v_due_date
    FROM public.tasks t
    WHERE t.id = NEW.task_id;
    
    -- Check if due date has passed
    IF v_due_date IS NOT NULL AND v_now > v_due_date THEN
        RAISE EXCEPTION 'Evidence cannot be submitted after due date.';
    END IF;
    
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.validate_evidence_due_date() OWNER TO postgres;

COMMENT ON FUNCTION public.validate_evidence_due_date() IS 'Validates that evidence cannot be submitted or updated after the task due date has passed. Raises exception if due date validation fails.';
