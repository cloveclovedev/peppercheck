CREATE OR REPLACE FUNCTION public.submit_evidence(
    p_task_id UUID,
    p_description TEXT,
    p_assets JSONB
)
RETURNS JSONB
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
        'ready'::public.evidence_status, -- Mark as ready since assets are uploaded
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
$function$;
