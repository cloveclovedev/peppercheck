CREATE OR REPLACE FUNCTION public.create_referee_blocked_date(
    p_start_date date,
    p_end_date date,
    p_reason text DEFAULT NULL
) RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_id uuid;
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION 'end_date must be >= start_date';
    END IF;

    INSERT INTO public.referee_blocked_dates (
        user_id, start_date, end_date, reason
    ) VALUES (
        v_user_id, p_start_date, p_end_date, p_reason
    ) RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

ALTER FUNCTION public.create_referee_blocked_date(date, date, text) OWNER TO postgres;
