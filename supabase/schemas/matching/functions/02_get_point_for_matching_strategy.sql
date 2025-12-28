CREATE OR REPLACE FUNCTION public.get_point_for_matching_strategy(p_strategy text)
RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    -- MVP: Strict validation. Only 'standard' is currently supported.
    IF p_strategy = 'standard' THEN
        RETURN 1;
    ELSE
        RAISE EXCEPTION 'Invalid matching strategy: %. Only standard is supported currently.', p_strategy;
    END IF;
END;
$$;

ALTER FUNCTION public.get_point_for_matching_strategy(text) OWNER TO postgres;
