CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout(p_judgement_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
BEGIN
    -- Get judgement with task info
    SELECT j.id, j.status, j.is_confirmed, j.is_evidence_timeout_confirmed, t.tasker_id
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
        RAISE EXCEPTION 'Only the tasker can confirm an evidence timeout';
    END IF;

    -- Validate status
    IF v_judgement.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in evidence_timeout status to confirm';
    END IF;

    -- Ensure settlement has completed (is_evidence_timeout_confirmed is set by settle_evidence_timeout trigger)
    IF v_judgement.is_evidence_timeout_confirmed != true THEN
        RAISE EXCEPTION 'Settlement has not completed yet';
    END IF;

    -- Idempotency
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Confirm (triggers task closure check via on_all_judgements_confirmed_close_task)
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
END;
$$;

ALTER FUNCTION public.confirm_evidence_timeout(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_evidence_timeout(uuid) IS 'Allows tasker to confirm/acknowledge an evidence timeout. Points were already settled by the settle_evidence_timeout trigger. Sets is_confirmed = true which triggers task closure check.';
