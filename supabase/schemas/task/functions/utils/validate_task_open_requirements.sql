CREATE OR REPLACE FUNCTION public.validate_task_open_requirements(
    p_user_id uuid,
    p_due_date timestamp with time zone,
    p_referee_requests jsonb[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_min_hours int;
    v_locked_points int;
    v_new_cost int := 0;
    v_wallet_balance int;
    v_req jsonb;
    v_strategy public.matching_strategy;
BEGIN
    -- 1. Due Date Validation
    SELECT (value::text)::int INTO v_min_hours
    FROM public.matching_config
    WHERE key = 'min_due_date_interval_hours';

    -- Strict Config Validation
    IF v_min_hours IS NULL THEN
        RAISE EXCEPTION 'Configuration missing for min_due_date_interval_hours in matching_config';
    END IF;

    IF p_due_date <= (now() + (v_min_hours || ' hours')::interval) THEN
        RAISE EXCEPTION 'Due date must be at least % hours from now', v_min_hours;
    END IF;

    -- 2. Point Validation
    -- Calculate New Task Cost
    IF p_referee_requests IS NOT NULL THEN
        FOREACH v_req IN ARRAY p_referee_requests
        LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;
            v_new_cost := v_new_cost + public.get_point_for_matching_strategy(v_strategy);
        END LOOP;
    END IF;

    -- Calculate Locked Points
    v_locked_points := public.calculate_locked_points_by_active_tasks(p_user_id);

    -- Get Wallet Balance
    SELECT balance INTO v_wallet_balance
    FROM public.point_wallets
    WHERE user_id = p_user_id;

    IF v_wallet_balance IS NULL THEN
        RAISE EXCEPTION 'Point wallet not found for user';
    END IF;

    -- Check Availability
    -- (Balance - Locked) >= New Cost
    IF (v_wallet_balance - v_locked_points) < v_new_cost THEN
         RAISE EXCEPTION 'Insufficient points. Balance: %, Locked: %, Required: %', v_wallet_balance, v_locked_points, v_new_cost;
    END IF;

END;
$$;

ALTER FUNCTION public.validate_task_open_requirements(uuid, timestamp with time zone, jsonb[]) OWNER TO postgres;
