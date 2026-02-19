CREATE OR REPLACE FUNCTION public.confirm_review_timeout(p_judgement_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
BEGIN
    SELECT j.id, j.status, j.is_confirmed, t.tasker_id
    INTO v_judgement
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    IF v_judgement.tasker_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the tasker can confirm a review timeout';
    END IF;

    IF v_judgement.status != 'review_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in review_timeout status to confirm';
    END IF;

    -- Idempotency
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Confirm (triggers on_all_judgements_confirmed_close_task)
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
END;
$$;

ALTER FUNCTION public.confirm_review_timeout(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_review_timeout(uuid) IS 'Allows tasker to confirm/acknowledge a review timeout. Points were already returned by settle_review_timeout. Sets is_confirmed = true which triggers task closure check.';
