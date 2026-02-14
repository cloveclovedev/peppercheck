CREATE OR REPLACE FUNCTION public.auto_score_timeout_referee() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
BEGIN
    -- Only process when is_confirmed changes from false to true
    IF TG_OP = 'UPDATE' AND OLD.is_confirmed = false AND NEW.is_confirmed = true THEN

        -- Get the judgement details with task info
        SELECT
            j.id,
            trr.matched_referee_id AS referee_id,
            j.status,
            t.tasker_id
        INTO v_judgement
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        WHERE j.id = NEW.id;

        -- If this is a review_timeout confirmation, automatically score referee negatively
        IF v_judgement.status = 'review_timeout' THEN
            INSERT INTO public.rating_histories (
                rater_id,
                ratee_id,
                judgement_id,
                rating_type,
                is_positive,
                comment
            ) VALUES (
                v_judgement.tasker_id,
                v_judgement.referee_id,
                v_judgement.id,
                'referee',
                false,
                'Automatic negative rating due to referee timeout'
            ) ON CONFLICT (judgement_id, rating_type) DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.auto_score_timeout_referee() OWNER TO postgres;

COMMENT ON FUNCTION public.auto_score_timeout_referee() IS 'Automatically scores referee negatively when a review_timeout is confirmed. Inserts into rating_histories with is_positive=false.';
