CREATE OR REPLACE FUNCTION public.confirm_judgement_and_rate_referee(p_task_id uuid, p_judgement_id uuid, p_ratee_id uuid, p_rating integer, p_comment text) RETURNS void
    LANGUAGE plpgsql
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

ALTER FUNCTION public.confirm_judgement_and_rate_referee(p_task_id uuid, p_judgement_id uuid, p_ratee_id uuid, p_rating integer, p_comment text) OWNER TO postgres;
