set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.is_task_referee(task_uuid uuid, user_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE STRICT SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM public.task_referee_requests
     WHERE task_id = task_uuid
       AND matched_referee_id = user_uuid
       AND status IN ('accepted', 'closed')
  );
$function$
;


