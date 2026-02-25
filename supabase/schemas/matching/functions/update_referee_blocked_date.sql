CREATE OR REPLACE FUNCTION public.update_referee_blocked_date(
    p_id uuid,
    p_start_date date,
    p_end_date date,
    p_reason text DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION 'end_date must be >= start_date';
    END IF;

    UPDATE public.referee_blocked_dates
    SET start_date = p_start_date,
        end_date = p_end_date,
        reason = p_reason
    WHERE id = p_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Blocked date not found or not owned by user';
    END IF;
END;
$$;

ALTER FUNCTION public.update_referee_blocked_date(uuid, date, date, text) OWNER TO postgres;
