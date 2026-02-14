CREATE OR REPLACE FUNCTION public.confirm_judgement_and_rate_referee(
    p_judgement_id uuid,
    p_is_positive boolean,
    p_comment text DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
    v_rows_affected integer;
BEGIN
    -- Get judgement details with task and referee info
    SELECT
        j.id,
        j.status,
        j.is_confirmed,
        trr.task_id,
        trr.matched_referee_id AS referee_id,
        t.tasker_id
    INTO v_judgement
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    -- Validate caller is the tasker
    IF v_judgement.tasker_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the tasker can confirm a judgement';
    END IF;

    -- Validate judgement status
    IF v_judgement.status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Judgement must be in approved or rejected status to confirm';
    END IF;

    -- Idempotency: if already confirmed, do nothing
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Insert rating (tasker rates referee)
    INSERT INTO public.rating_histories (
        judgement_id,
        ratee_id,
        rater_id,
        rating_type,
        is_positive,
        comment
    ) VALUES (
        p_judgement_id,
        v_judgement.referee_id,
        (SELECT auth.uid()),
        'referee',
        p_is_positive,
        p_comment
    );

    -- Confirm judgement
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Failed to update judgement confirmation status';
    END IF;
END;
$$;

ALTER FUNCTION public.confirm_judgement_and_rate_referee(uuid, boolean, text) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_judgement_and_rate_referee(uuid, boolean, text) IS 'Atomically confirms a judgement and records a binary rating for the referee. Called by the tasker after reviewing the referee''s judgement. Only valid for approved/rejected judgements.';
