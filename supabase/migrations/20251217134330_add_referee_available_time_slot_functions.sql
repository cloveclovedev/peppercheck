set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.create_referee_available_time_slot(p_dow integer, p_start_min integer, p_end_min integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_new_id uuid;
BEGIN
    v_user_id := auth.uid();

    -- Validation: Start < End
    IF p_start_min >= p_end_min THEN
        RAISE EXCEPTION 'Start time must be before end time';
    END IF;

    -- Validation: Check for overlaps
    -- Overlap condition: (StartA < EndB) and (EndA > StartB)
    IF EXISTS (
        SELECT 1 FROM public.referee_available_time_slots
        WHERE user_id = v_user_id
          AND dow = p_dow
          AND is_active = true
          AND p_start_min < end_min
          AND p_end_min > start_min
    ) THEN
        RAISE EXCEPTION 'Time slot overlaps with an existing active slot';
    END IF;

    INSERT INTO public.referee_available_time_slots (
        user_id,
        dow,
        start_min,
        end_min
    ) VALUES (
        v_user_id,
        p_dow,
        p_start_min,
        p_end_min
    ) RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_referee_available_time_slot(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    DELETE FROM public.referee_available_time_slots
    WHERE id = p_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Time slot not found or permission denied';
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_referee_available_time_slot(p_id uuid, p_dow integer, p_start_min integer, p_end_min integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    -- Validation: Start < End
    IF p_start_min >= p_end_min THEN
        RAISE EXCEPTION 'Start time must be before end time';
    END IF;

    -- Validation: Check for overlaps (excluding self)
    IF EXISTS (
        SELECT 1 FROM public.referee_available_time_slots
        WHERE user_id = v_user_id
          AND id != p_id
          AND dow = p_dow
          AND is_active = true
          AND p_start_min < end_min
          AND p_end_min > start_min
    ) THEN
        RAISE EXCEPTION 'Time slot overlaps with an existing active slot';
    END IF;

    UPDATE public.referee_available_time_slots
    SET
        dow = p_dow,
        start_min = p_start_min,
        end_min = p_end_min,
        updated_at = now()
    WHERE id = p_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Time slot not found or permission denied';
    END IF;
END;
$function$
;


