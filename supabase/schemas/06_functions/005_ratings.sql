-- Functions grouped in 005_ratings.sql
CREATE OR REPLACE FUNCTION "public"."confirm_judgement_and_rate_referee"("p_task_id" "uuid", "p_judgement_id" "uuid", "p_ratee_id" "uuid", "p_rating" integer, "p_comment" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    SET search_path = ''
    AS $$
DECLARE
  v_is_confirmed boolean;
  v_rows_affected integer;
BEGIN
  -- Idempotency check: if already confirmed, do nothing
  SELECT is_confirmed INTO v_is_confirmed 
  FROM public.judgements WHERE id = p_judgement_id;
  
  IF v_is_confirmed = TRUE THEN
    RETURN;
  END IF;

  -- Atomic operation: Rating insertion + Judgement confirmation
  INSERT INTO public.rating_histories (task_id, judgement_id, ratee_id, rating_type, rating, comment)
  VALUES (p_task_id, p_judgement_id, p_ratee_id, 'referee', p_rating, p_comment);
  
  UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
  
  -- Check if the UPDATE actually affected any rows
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  
  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION 'Failed to update judgement confirmation status. No rows affected. This may be due to permission restrictions.';
  END IF;

  -- NOTE: task_referee_requests status update is now handled automatically by trigger
  -- No manual update needed here
    
END;
$$;

ALTER FUNCTION "public"."confirm_judgement_and_rate_referee"("p_task_id" "uuid", "p_judgement_id" "uuid", "p_ratee_id" "uuid", "p_rating" integer, "p_comment" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."set_rater_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
  -- Only set rater_id if it's not already provided
  IF NEW.rater_id IS NULL THEN
    NEW.rater_id := (select auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."set_rater_id"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_user_ratings"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
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

ALTER FUNCTION "public"."update_user_ratings"() OWNER TO "postgres";
