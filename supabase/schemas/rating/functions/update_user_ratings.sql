CREATE OR REPLACE FUNCTION public.update_user_ratings() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    affected_user_id uuid;
    v_positive integer;
    v_total integer;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.ratee_id;
    ELSE
        affected_user_id := NEW.ratee_id;
    END IF;

    -- Recalculate tasker ratings
    SELECT
        COUNT(*) FILTER (WHERE is_positive = true),
        COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'tasker';

    UPDATE public.user_ratings
    SET
        tasker_positive_count = v_positive,
        tasker_total_count = v_total,
        tasker_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    -- Recalculate referee ratings
    SELECT
        COUNT(*) FILTER (WHERE is_positive = true),
        COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'referee';

    UPDATE public.user_ratings
    SET
        referee_positive_count = v_positive,
        referee_total_count = v_total,
        referee_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

ALTER FUNCTION public.update_user_ratings() OWNER TO postgres;
