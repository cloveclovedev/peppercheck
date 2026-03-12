CREATE OR REPLACE FUNCTION public.route_referee_reward(
    p_request_id uuid,
    p_referee_id uuid,
    p_cost integer,
    p_reason public.reward_reason,
    p_description text,
    p_related_id uuid
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_is_obligation boolean;
    v_obligation_id uuid;
BEGIN
    SELECT is_obligation INTO v_is_obligation
    FROM public.task_referee_requests
    WHERE id = p_request_id;

    IF v_is_obligation IS NULL THEN
        RAISE EXCEPTION 'Task referee request not found: %', p_request_id;
    END IF;

    IF v_is_obligation THEN
        -- Fulfill oldest pending obligation (FIFO)
        SELECT id INTO v_obligation_id
        FROM public.referee_obligations
        WHERE user_id = p_referee_id
        AND status = 'pending'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE;

        IF v_obligation_id IS NOT NULL THEN
            UPDATE public.referee_obligations
            SET status = 'fulfilled'::public.referee_obligation_status,
                fulfill_request_id = p_request_id,
                fulfilled_at = now()
            WHERE id = v_obligation_id;
        END IF;
        -- No reward granted for obligation fulfillment
    ELSE
        PERFORM public.grant_reward(p_referee_id, p_cost, p_reason, p_description, p_related_id);
    END IF;
END;
$$;

ALTER FUNCTION public.route_referee_reward(uuid, uuid, integer, public.reward_reason, text, uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.route_referee_reward(uuid, uuid, integer, public.reward_reason, text, uuid) IS 'Routes referee compensation: if is_obligation on the request, fulfills oldest pending obligation instead of granting reward points.';
