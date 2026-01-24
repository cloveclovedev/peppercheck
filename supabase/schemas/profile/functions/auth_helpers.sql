CREATE OR REPLACE FUNCTION public.is_task_referee(task_uuid uuid, user_uuid uuid) RETURNS boolean
    LANGUAGE sql STABLE STRICT SECURITY DEFINER
    SET row_security TO 'off'
    SET search_path TO ''
    AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.task_referee_requests
     WHERE task_id = task_uuid
       AND matched_referee_id = user_uuid
       AND status = 'accepted'
  );
$$;

ALTER FUNCTION public.is_task_referee(task_uuid uuid, user_uuid uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.is_task_referee(task_uuid uuid, user_uuid uuid) IS 'Return true when user_uuid is a referee of task_uuid. NULL input ⇒ NULL.';

CREATE OR REPLACE FUNCTION public.is_task_referee_candidate(task_uuid uuid, user_uuid uuid) RETURNS boolean
    LANGUAGE sql STABLE STRICT SECURITY DEFINER
    SET row_security TO 'off'
    SET search_path TO ''
    AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.task_referee_requests
     WHERE task_id = task_uuid
       AND matched_referee_id = user_uuid
       AND status = 'matched'
  );
$$;

ALTER FUNCTION public.is_task_referee_candidate(task_uuid uuid, user_uuid uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.is_task_referee_candidate(task_uuid uuid, user_uuid uuid) IS 'Return true when user_uuid is a referee candidate for task_uuid. NULL input ⇒ NULL.';

CREATE OR REPLACE FUNCTION public.is_task_tasker(task_uuid uuid, user_uuid uuid) RETURNS boolean
    LANGUAGE sql STABLE STRICT SECURITY DEFINER
    SET row_security TO 'off'
    SET search_path TO ''
    AS $$
  SELECT tasker_id = user_uuid
    FROM public.tasks
   WHERE id = task_uuid;
$$;

ALTER FUNCTION public.is_task_tasker(task_uuid uuid, user_uuid uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.is_task_tasker(task_uuid uuid, user_uuid uuid) IS 'Return true when user_uuid is the tasker of task_uuid. NULL or non‑existent task ⇒ NULL (STRICT).';
