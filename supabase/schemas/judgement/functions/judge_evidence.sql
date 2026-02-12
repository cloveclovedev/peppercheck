CREATE OR REPLACE FUNCTION public.judge_evidence(
    p_judgement_id uuid,
    p_status public.judgement_status,
    p_comment text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_current_status public.judgement_status;
    v_referee_id uuid;
BEGIN
    -- 1. Input Validation
    IF p_status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Status must be approved or rejected';
    END IF;

    IF p_comment IS NULL OR trim(p_comment) = '' THEN
        RAISE EXCEPTION 'Comment is required';
    END IF;

    -- 2. Authorization & Status Check
    SELECT j.status, trr.matched_referee_id
    INTO v_current_status, v_referee_id
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    IF v_referee_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the assigned referee can judge evidence';
    END IF;

    IF v_current_status != 'in_review' THEN
        RAISE EXCEPTION 'Judgement must be in_review status to approve or reject';
    END IF;

    -- 3. Update Judgement
    UPDATE public.judgements
    SET
        status = p_status,
        comment = trim(p_comment)
    WHERE id = p_judgement_id;

END;
$$;

ALTER FUNCTION public.judge_evidence(uuid, public.judgement_status, text) OWNER TO postgres;
