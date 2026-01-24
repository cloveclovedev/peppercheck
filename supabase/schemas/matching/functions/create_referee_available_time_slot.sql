CREATE OR REPLACE FUNCTION public.create_referee_available_time_slot(
    p_dow integer,
    p_start_min integer,
    p_end_min integer
) RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
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
$$;

ALTER FUNCTION public.create_referee_available_time_slot(integer, integer, integer) OWNER TO postgres;
