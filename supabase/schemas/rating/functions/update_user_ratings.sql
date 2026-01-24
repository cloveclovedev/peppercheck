CREATE OR REPLACE FUNCTION public.update_user_ratings() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    affected_user_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.ratee_id;
    ELSE
        affected_user_id := NEW.ratee_id;
    END IF;

    -- Recalculate tasker_rating and tasker_rating_count
    UPDATE public.user_ratings
    SET
        tasker_rating = COALESCE((SELECT AVG(rating)::numeric FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'tasker'), 0),
        tasker_rating_count = (SELECT COUNT(*)::integer FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'tasker'),
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    -- Recalculate referee_rating and referee_rating_count
    UPDATE public.user_ratings
    SET
        referee_rating = COALESCE((SELECT AVG(rating)::numeric FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'referee'), 0),
        referee_rating_count = (SELECT COUNT(*)::integer FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'referee'),
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
