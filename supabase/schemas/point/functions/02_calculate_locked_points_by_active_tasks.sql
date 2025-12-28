CREATE OR REPLACE FUNCTION public.calculate_locked_points_by_active_tasks(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_points integer;
BEGIN
    -- Sum points for all active requests that represent a liability (locked points)
    -- Active requests: pending, matched, accepted, payment_processing
    -- Active tasks: Not closed/completed/expired (Drafts usually don't have requests, but if they do, we might count them if request status is pending)
    
    SELECT COALESCE(SUM(public.get_point_for_matching_strategy(req.matching_strategy)), 0)
    INTO v_total_points
    FROM public.task_referee_requests req
    JOIN public.tasks t ON req.task_id = t.id
    WHERE t.tasker_id = p_user_id
    AND req.status IN ('pending', 'matched', 'accepted', 'payment_processing')
    -- Filter out terminal task states just in case
    AND t.status NOT IN ('closed', 'completed', 'expired', 'self_completed');

    RETURN v_total_points;
END;
$$;

ALTER FUNCTION public.calculate_locked_points_by_active_tasks(uuid) OWNER TO postgres;
