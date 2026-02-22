CREATE OR REPLACE FUNCTION public.resubmit_evidence(
    p_evidence_id UUID,
    p_description TEXT,
    p_assets_to_add JSONB DEFAULT NULL,
    p_asset_ids_to_remove UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_task_id UUID;
    v_asset JSONB;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    -- 1. Validation
    IF p_description IS NULL OR trim(p_description) = '' THEN
        RAISE EXCEPTION 'Description is required';
    END IF;

    -- 2. Authorization & Status Check
    -- Resubmission requires: rejected, reopen_count < 1, due_date > now(), is_confirmed = false
    SELECT te.task_id INTO v_task_id
    FROM public.task_evidences te
    JOIN public.tasks t ON t.id = te.task_id
    JOIN public.task_referee_requests trr ON trr.task_id = t.id
    JOIN public.judgements j ON j.id = trr.id
    WHERE te.id = p_evidence_id
      AND t.tasker_id = auth.uid()
      AND j.status = 'rejected'
      AND j.reopen_count < 1
      AND j.is_confirmed = false
      AND t.due_date > v_now;

    IF v_task_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized or evidence not in valid state for resubmission';
    END IF;

    -- 3. Update evidence FIRST (while judgement is still 'rejected')
    -- Evidence trigger will skip notification because judgement status is 'rejected'
    UPDATE public.task_evidences
    SET description = p_description,
        updated_at = v_now
    WHERE id = p_evidence_id;

    -- 3.1 Remove specified assets
    IF p_asset_ids_to_remove IS NOT NULL AND array_length(p_asset_ids_to_remove, 1) > 0 THEN
        DELETE FROM public.task_evidence_assets
        WHERE id = ANY(p_asset_ids_to_remove)
          AND evidence_id = p_evidence_id;
    END IF;

    -- 3.2 Add new assets
    IF p_assets_to_add IS NOT NULL AND jsonb_array_length(p_assets_to_add) > 0 THEN
        FOR v_asset IN SELECT * FROM jsonb_array_elements(p_assets_to_add)
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
                p_evidence_id,
                v_asset->>'file_url',
                (v_asset->>'file_size_bytes')::BIGINT,
                v_asset->>'content_type',
                v_now,
                'completed',
                v_asset->>'public_url'
            );
        END LOOP;
    END IF;

    -- 4. Update judgement SECOND (triggers resubmission notification)
    -- Judgement trigger detects rejected → in_review with reopen_count > 0
    UPDATE public.judgements j
    SET
        status = 'in_review',
        reopen_count = reopen_count + 1,
        updated_at = v_now
    FROM public.task_referee_requests trr
    WHERE
        j.id = trr.id
        AND trr.task_id = v_task_id
        AND j.status = 'rejected'
        AND j.reopen_count < 1;

    RETURN jsonb_build_object(
        'success', true,
        'evidence_id', p_evidence_id
    );
END;
$function$;
