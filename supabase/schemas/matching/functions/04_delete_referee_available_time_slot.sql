CREATE OR REPLACE FUNCTION public.delete_referee_available_time_slot(
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

    DELETE FROM public.referee_available_time_slots
    WHERE id = p_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Time slot not found or permission denied';
    END IF;
END;
$$;

ALTER FUNCTION public.delete_referee_available_time_slot(uuid) OWNER TO postgres;
