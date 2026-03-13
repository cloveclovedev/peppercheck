CREATE OR REPLACE FUNCTION public.check_account_deletable()
RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_reasons text[] := '{}';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check open tasks as tasker
    IF EXISTS (
        SELECT 1 FROM public.tasks
        WHERE tasker_id = v_user_id AND status = 'open'
    ) THEN
        v_reasons := array_append(v_reasons, 'open_tasks');
    END IF;

    -- Check active referee requests
    IF EXISTS (
        SELECT 1 FROM public.task_referee_requests
        WHERE matched_referee_id = v_user_id
          AND status IN ('matched', 'accepted', 'payment_processing')
    ) THEN
        v_reasons := array_append(v_reasons, 'active_referee_requests');
    END IF;

    RETURN jsonb_build_object(
        'deletable', array_length(v_reasons, 1) IS NULL,
        'reasons', to_jsonb(v_reasons)
    );
END;
$$;

ALTER FUNCTION public.check_account_deletable() OWNER TO postgres;
