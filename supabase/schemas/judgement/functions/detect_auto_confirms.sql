CREATE OR REPLACE FUNCTION public.detect_auto_confirms() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_now TIMESTAMP WITH TIME ZONE;
    v_rec RECORD;
    v_cost integer;
    v_processed_count integer := 0;
BEGIN
    v_now := NOW();

    -- Process each eligible judgement individually (need per-row settlement for approved/rejected)
    FOR v_rec IN
        SELECT
            j.id AS judgement_id,
            j.status,
            t.tasker_id,
            trr.matched_referee_id AS referee_id,
            trr.matching_strategy,
            t.title AS task_title,
            trr.task_id
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON trr.id = j.id
        JOIN public.tasks t ON t.id = trr.task_id
        WHERE j.is_confirmed = false
        AND j.status IN ('approved', 'rejected', 'review_timeout', 'evidence_timeout')
        AND v_now > (t.due_date + INTERVAL '3 days')
        FOR UPDATE OF j SKIP LOCKED
    LOOP
        -- Settlement for approved/rejected (not yet settled)
        IF v_rec.status IN ('approved', 'rejected') THEN
            v_cost := public.get_point_for_matching_strategy(v_rec.matching_strategy);

            -- Consume locked points from tasker
            PERFORM public.consume_points(
                v_rec.tasker_id,
                v_cost,
                'matching_settled'::public.point_reason,
                'Auto-confirmed (judgement ' || v_rec.judgement_id || ')',
                v_rec.judgement_id
            );

            -- Grant reward to referee
            PERFORM public.grant_reward(
                v_rec.referee_id,
                v_cost,
                'review_completed'::public.reward_reason,
                'Auto-confirmed (judgement ' || v_rec.judgement_id || ')',
                v_rec.judgement_id
            );

            -- Auto-positive rating
            INSERT INTO public.rating_histories (
                rater_id,
                ratee_id,
                judgement_id,
                rating_type,
                is_positive,
                comment
            ) VALUES (
                v_rec.tasker_id,
                v_rec.referee_id,
                v_rec.judgement_id,
                'referee',
                true,
                NULL
            ) ON CONFLICT (judgement_id, rating_type) DO NOTHING;
        END IF;

        -- Set auto-confirmed and confirmed flags
        UPDATE public.judgements
        SET is_auto_confirmed = true, is_confirmed = true, updated_at = v_now
        WHERE id = v_rec.judgement_id;

        v_processed_count := v_processed_count + 1;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'auto_confirmed_count', v_processed_count,
        'processed_at', v_now
    );
END;
$$;

ALTER FUNCTION public.detect_auto_confirms() OWNER TO postgres;

COMMENT ON FUNCTION public.detect_auto_confirms() IS 'Detects judgements eligible for auto-confirm (is_confirmed=false, past due_date + 3 days). Settles points/rewards for approved/rejected, sets is_auto_confirmed and is_confirmed. Called by pg_cron every hour.';
