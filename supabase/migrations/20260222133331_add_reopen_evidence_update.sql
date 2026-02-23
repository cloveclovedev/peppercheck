drop function if exists "public"."reopen_judgement"(p_judgement_id uuid);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.resubmit_evidence(p_evidence_id uuid, p_description text, p_assets_to_add jsonb DEFAULT NULL::jsonb, p_asset_ids_to_remove uuid[] DEFAULT NULL::uuid[])
 RETURNS jsonb
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
$function$
;

CREATE OR REPLACE FUNCTION public.update_evidence(p_evidence_id uuid, p_description text, p_assets_to_add jsonb DEFAULT NULL::jsonb, p_asset_ids_to_remove uuid[] DEFAULT NULL::uuid[])
 RETURNS jsonb
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
    -- Must be tasker AND judgement must be in_review
    SELECT te.task_id INTO v_task_id
    FROM public.task_evidences te
    JOIN public.tasks t ON t.id = te.task_id
    JOIN public.task_referee_requests trr ON trr.task_id = t.id
    JOIN public.judgements j ON j.id = trr.id
    WHERE te.id = p_evidence_id
      AND t.tasker_id = auth.uid()
      AND j.status = 'in_review';

    IF v_task_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized or evidence not in valid state for update';
    END IF;

    -- 3. Update description
    UPDATE public.task_evidences
    SET description = p_description,
        updated_at = v_now
    WHERE id = p_evidence_id;

    -- 4. Remove specified assets
    IF p_asset_ids_to_remove IS NOT NULL AND array_length(p_asset_ids_to_remove, 1) > 0 THEN
        DELETE FROM public.task_evidence_assets
        WHERE id = ANY(p_asset_ids_to_remove)
          AND evidence_id = p_evidence_id;
    END IF;

    -- 5. Add new assets
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

    RETURN jsonb_build_object(
        'success', true,
        'evidence_id', p_evidence_id
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.on_judgements_status_changed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_notification_key text;
    v_recipient_id uuid;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Resolve task info via task_referee_requests
    SELECT t.id, t.tasker_id, t.title, trr.matched_referee_id
    INTO v_task_id, v_tasker_id, v_task_title, v_referee_id
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Determine notification based on new status
    CASE NEW.status
        WHEN 'approved' THEN
            v_notification_key := 'notification_judgement_approved';
            v_recipient_id := v_tasker_id;
        WHEN 'rejected' THEN
            v_notification_key := 'notification_judgement_rejected';
            v_recipient_id := v_tasker_id;
        WHEN 'in_review' THEN
            -- Resubmission: rejected → in_review with reopen_count > 0
            IF OLD.status = 'rejected' AND NEW.reopen_count > 0 THEN
                v_notification_key := 'notification_evidence_resubmitted';
                v_recipient_id := v_referee_id;
            ELSE
                RETURN NEW;
            END IF;
        ELSE
            RETURN NEW;
    END CASE;

    -- Send notification
    PERFORM public.notify_event(
        v_recipient_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.on_task_evidences_upserted_notify_referee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_referee_id uuid;
    v_task_title text;
    v_notification_key text;
    v_judgement_status text;
BEGIN
    -- 1. Identify Recipient (Referee) and current judgement status
    SELECT trr.matched_referee_id, j.status::text
    INTO v_referee_id, v_judgement_status
    FROM public.task_referee_requests trr
    JOIN public.judgements j ON j.id = trr.id
    WHERE trr.task_id = NEW.task_id;

    IF v_referee_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Determine Event Key
    IF TG_OP = 'INSERT' THEN
        v_notification_key := 'notification_evidence_submitted';
    ELSIF TG_OP = 'UPDATE' THEN
        -- During resubmission, evidence is updated while judgement is still 'rejected'.
        -- The judgement status change trigger handles the resubmission notification.
        IF v_judgement_status = 'rejected' THEN
            RETURN NEW;
        END IF;
        v_notification_key := 'notification_evidence_updated';
    END IF;

    -- 3. Identify Task Details
    SELECT title INTO v_task_title FROM public.tasks WHERE id = NEW.task_id;

    -- 4. Invoke Notification
    PERFORM public.notify_event(
        v_referee_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', NEW.task_id)
    );

    RETURN NEW;
END;
$function$
;

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
    IF NOT EXISTS (
        SELECT 1
        FROM public.tasks t
        JOIN public.task_referee_requests trr ON trr.task_id = t.id
        JOIN public.judgements j ON j.id = trr.id
        WHERE t.id = p_task_id
          AND t.tasker_id = auth.uid()
          AND j.status = 'awaiting_evidence'
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
    UPDATE public.judgements j
    SET
        status = 'in_review',
        updated_at = v_now
    FROM public.task_referee_requests trr
    WHERE
        j.id = trr.id
        AND trr.task_id = p_task_id
        AND j.status = 'awaiting_evidence';

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


