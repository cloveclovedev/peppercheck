CREATE OR REPLACE FUNCTION public.delete_referee_blocked_date(
    p_id uuid
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

    DELETE FROM public.referee_blocked_dates
    WHERE id = p_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Blocked date not found or not owned by user';
    END IF;
END;
$$;

ALTER FUNCTION public.delete_referee_blocked_date(uuid) OWNER TO postgres;
