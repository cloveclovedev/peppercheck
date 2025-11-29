-- Returns true if the user has failed billing jobs at or above max_retry_attempts
CREATE OR REPLACE FUNCTION public.is_billing_action_required(p_user_id uuid DEFAULT NULL)
RETURNS boolean
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
DECLARE
  v_target_user_id uuid;
  v_max_attempts integer;
  v_is_billing_action_required boolean;
BEGIN
  v_target_user_id := COALESCE(p_user_id, auth.uid());

  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'is_billing_action_required: user_id not provided and auth.uid() is null';
  END IF;

  SELECT max_retry_attempts
    INTO v_max_attempts
    FROM public.billing_settings
   WHERE id = 1;

  IF v_max_attempts IS NULL THEN
    RAISE EXCEPTION 'is_billing_action_required: billing_settings missing';
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM public.billing_jobs bj
      JOIN public.task_referee_requests trr ON trr.id = bj.referee_request_id
      JOIN public.tasks t ON t.id = trr.task_id
     WHERE t.tasker_id = v_target_user_id
       AND bj.status = 'failed'
       AND bj.attempt_count >= v_max_attempts
  ) INTO v_is_billing_action_required;

  RETURN v_is_billing_action_required;
END;
$$;

COMMENT ON FUNCTION public.is_billing_action_required(uuid)
  IS 'Returns true if the user has failed billing jobs at/over retry limit; defaults to auth.uid.';
