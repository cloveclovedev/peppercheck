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
$$;

ALTER FUNCTION public.auto_score_timeout_referee() OWNER TO postgres;

COMMENT ON FUNCTION public.auto_score_timeout_referee() IS 'Corrected version: Automatically scores referee as 0 when a judgement_timeout is confirmed by the tasker. Only inserts into rating_histories - user_ratings table is updated automatically by existing trigger system. This maintains consistency with the existing rating architecture.';
