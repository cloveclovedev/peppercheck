set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_judgement_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
BEGIN
    -- Only execute when is_confirmed changes from FALSE to TRUE
    IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN

        -- Skip if auto-confirmed (handled by on_judgement_confirmed_notify)
        IF NEW.is_auto_confirmed THEN
            RETURN NEW;
        END IF;

        -- Notify referee only for approved/rejected judgements
        IF NEW.status IN ('approved', 'rejected') THEN
            SELECT trr.matched_referee_id, trr.task_id, t.title
            INTO v_referee_id, v_task_id, v_task_title
            FROM public.task_referee_requests trr
            JOIN public.tasks t ON t.id = trr.task_id
            WHERE trr.id = NEW.id;

            IF FOUND THEN
                PERFORM public.notify_event(
                    v_referee_id,
                    'notification_judgement_confirmed_referee',
                    ARRAY[v_task_title],
                    jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
                );
            END IF;
        END IF;

    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.on_judgements_status_changed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_notification_key text;
    v_recipient_id uuid;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Resolve task info via task_referee_requests
    SELECT t.id, t.tasker_id, t.title, trr.matched_referee_id
    INTO v_task_id, v_tasker_id, v_task_title, v_referee_id
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Determine notification based on new status
    CASE NEW.status
        WHEN 'approved' THEN
            v_notification_key := 'notification_judgement_approved_tasker';
            v_recipient_id := v_tasker_id;
        WHEN 'rejected' THEN
            v_notification_key := 'notification_judgement_rejected_tasker';
            v_recipient_id := v_tasker_id;
        WHEN 'in_review' THEN
            -- Resubmission: rejected → in_review with reopen_count > 0
            IF OLD.status = 'rejected' AND NEW.reopen_count > 0 THEN
                v_notification_key := 'notification_evidence_resubmitted_referee';
                v_recipient_id := v_referee_id;
            ELSE
                RETURN NEW;
            END IF;
        ELSE
            RETURN NEW;
    END CASE;

    -- Send notification
    PERFORM public.notify_event(
        v_recipient_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.on_task_evidences_upserted_notify_referee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_referee_id uuid;
    v_task_title text;
    v_notification_key text;
    v_judgement_status text;
BEGIN
    -- 1. Identify Recipient (Referee) and current judgement status
    SELECT trr.matched_referee_id, j.status::text
    INTO v_referee_id, v_judgement_status
    FROM public.task_referee_requests trr
    JOIN public.judgements j ON j.id = trr.id
    WHERE trr.task_id = NEW.task_id;

    IF v_referee_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Determine Event Key
    IF TG_OP = 'INSERT' THEN
        v_notification_key := 'notification_evidence_submitted_referee';
    ELSIF TG_OP = 'UPDATE' THEN
        -- During resubmission, evidence is updated while judgement is still 'rejected'.
        -- The judgement status change trigger handles the resubmission notification.
        IF v_judgement_status = 'rejected' THEN
            RETURN NEW;
        END IF;
        v_notification_key := 'notification_evidence_updated_referee';
    END IF;

    -- 3. Identify Task Details
    SELECT title INTO v_task_title FROM public.tasks WHERE id = NEW.task_id;

    -- 4. Invoke Notification
    PERFORM public.notify_event(
        v_referee_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', NEW.task_id)
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.prepare_monthly_payouts(p_currency text DEFAULT 'JPY'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_rate integer;
    v_batch_date date := CURRENT_DATE;
    v_wallet RECORD;
    v_pending_count integer := 0;
    v_skipped_count integer := 0;
    v_connect_account_id text;
    v_payouts_enabled boolean;
BEGIN
    -- Guard: only run on the actual last day of the month
    IF v_batch_date != (date_trunc('month', v_batch_date) + interval '1 month' - interval '1 day')::date THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'Not last day of month');
    END IF;

    -- Get active exchange rate
    SELECT rate_per_point INTO v_rate
    FROM public.reward_exchange_rates
    WHERE currency = p_currency AND active = true;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'No active exchange rate for currency: %', p_currency;
    END IF;

    -- Idempotency: skip if payouts already prepared for this batch_date
    IF EXISTS (SELECT 1 FROM public.reward_payouts WHERE batch_date = v_batch_date AND currency = p_currency LIMIT 1) THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'Payouts already prepared for ' || v_batch_date);
    END IF;

    -- Process each wallet with balance > 0
    FOR v_wallet IN
        SELECT user_id, balance FROM public.reward_wallets WHERE balance > 0
    LOOP
        -- Check Connect account status
        -- profiles.id = auth.users.id = stripe_accounts.profile_id
        SELECT sa.stripe_connect_account_id, sa.payouts_enabled
        INTO v_connect_account_id, v_payouts_enabled
        FROM public.stripe_accounts sa
        WHERE sa.profile_id = v_wallet.user_id;

        IF v_connect_account_id IS NOT NULL AND v_payouts_enabled = true THEN
            -- User is ready for payout
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'pending', v_batch_date
            );
            v_pending_count := v_pending_count + 1;
        ELSE
            -- User not ready — skip and notify
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date, error_message
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'skipped', v_batch_date,
                'Connect account not ready (payouts_enabled=false or no account)'
            );
            v_skipped_count := v_skipped_count + 1;

            -- Send reminder notification
            PERFORM public.notify_event(
                v_wallet.user_id,
                'notification_payout_connect_required_referee',
                NULL,
                jsonb_build_object('batch_date', v_batch_date)
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'pending', v_pending_count,
        'skipped', v_skipped_count,
        'batch_date', v_batch_date,
        'currency', p_currency,
        'rate_per_point', v_rate
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.process_matching(p_request_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_request RECORD;
    v_task RECORD;
    v_matched_referee_id UUID;
    v_due_date TIMESTAMP WITH TIME ZONE;
    v_available_referees UUID[];
    v_min_workload INTEGER;
    v_least_busy_referees UUID[];
    v_selected_referee UUID;
    v_debug_info JSONB;
BEGIN
    v_debug_info := jsonb_build_object();

    -- Get request details
    SELECT
        trr.id,
        trr.task_id,
        trr.matching_strategy,
        trr.preferred_referee_id,
        trr.status
    INTO v_request
    FROM public.task_referee_requests trr
    WHERE trr.id = p_request_id;

    v_debug_info := v_debug_info || jsonb_build_object('request', row_to_json(v_request));

    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Request not found',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    -- Skip if already processed
    IF v_request.status != 'pending' THEN
        RETURN json_build_object(
            'success', true,
            'message', 'Request already processed',
            'status', v_request.status,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    -- Get task details
    SELECT t.id, t.due_date, t.tasker_id, t.status, t.title
    INTO v_task
    FROM public.tasks t
    WHERE t.id = v_request.task_id;

    v_debug_info := v_debug_info || jsonb_build_object('task', row_to_json(v_task));

    IF NOT FOUND OR v_task.status NOT IN ('open') THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Task not found or not available for matching',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    v_due_date := v_task.due_date;

    -- Process matching based on strategy
    CASE v_request.matching_strategy
        WHEN 'standard' THEN
            SELECT ARRAY_AGG(DISTINCT referee_id) INTO v_available_referees
            FROM (
                SELECT
                    rats.user_id as referee_id
                FROM public.referee_available_time_slots rats
                INNER JOIN public.profiles p ON rats.user_id = p.id
                WHERE rats.is_active = true
                AND rats.user_id != v_task.tasker_id
                AND EXTRACT(DOW FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) = rats.dow
                AND (EXTRACT(HOUR FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60 +
                     EXTRACT(MINUTE FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) >= rats.start_min
                AND (EXTRACT(HOUR FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60 +
                     EXTRACT(MINUTE FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) <= rats.end_min
            ) available_refs;

            v_debug_info := v_debug_info || jsonb_build_object(
                'available_referees', v_available_referees,
                'available_referees_count', COALESCE(array_length(v_available_referees, 1), 0)
            );

            IF COALESCE(array_length(v_available_referees, 1), 0) = 0 THEN
                v_matched_referee_id := NULL;
            ELSE
                SELECT MIN(workload_count) INTO v_min_workload
                FROM (
                    SELECT
                        COALESCE(COUNT(j.id), 0) as workload_count
                    FROM (SELECT unnest(v_available_referees) as referee_id) refs
                    LEFT JOIN public.task_referee_requests trr ON trr.matched_referee_id = refs.referee_id
                        AND trr.status IN ('accepted', 'matched') 
                    LEFT JOIN public.judgements j ON j.id = trr.id
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'review_timeout')
                    GROUP BY refs.referee_id
                ) workloads;

                v_debug_info := v_debug_info || jsonb_build_object('min_workload', v_min_workload);

                SELECT array_agg(referee_id) INTO v_least_busy_referees
                FROM (
                    SELECT
                        refs.referee_id,
                        COALESCE(COUNT(j.id), 0) as workload_count
                    FROM (SELECT unnest(v_available_referees) as referee_id) refs
                    LEFT JOIN public.task_referee_requests trr ON trr.matched_referee_id = refs.referee_id
                        AND trr.status IN ('accepted', 'matched')
                    LEFT JOIN public.judgements j ON j.id = trr.id
                        AND j.status IN ('awaiting_evidence', 'in_review', 'rejected', 'review_timeout')
                    GROUP BY refs.referee_id
                    HAVING COALESCE(COUNT(j.id), 0) = v_min_workload
                ) least_busy;

                v_debug_info := v_debug_info || jsonb_build_object(
                    'least_busy_referees', v_least_busy_referees,
                    'least_busy_referees_count', COALESCE(array_length(v_least_busy_referees, 1), 0)
                );

                IF COALESCE(array_length(v_least_busy_referees, 1), 0) > 0 THEN
                    v_selected_referee := v_least_busy_referees[1 + floor(random() * array_length(v_least_busy_referees, 1))::INTEGER];
                    v_matched_referee_id := v_selected_referee;
                    v_debug_info := v_debug_info || jsonb_build_object('selected_referee', v_selected_referee);
                ELSE
                    v_matched_referee_id := NULL;
                END IF;
            END IF;

        WHEN 'premium' THEN
            v_matched_referee_id := NULL;

        WHEN 'direct' THEN
            IF v_request.preferred_referee_id IS NOT NULL THEN
                v_matched_referee_id := v_request.preferred_referee_id;
            ELSE
                v_matched_referee_id := NULL;
            END IF;

        ELSE
            RETURN json_build_object(
                'success', false,
                'error', 'Unknown matching strategy',
                'request_id', p_request_id,
                'strategy', v_request.matching_strategy,
                'debug', v_debug_info
            );
    END CASE;

    IF v_matched_referee_id IS NOT NULL THEN
        UPDATE public.task_referee_requests
        SET
            status = 'accepted'::public.referee_request_status,
            matched_referee_id = v_matched_referee_id,
            responded_at = NOW()
        WHERE id = p_request_id;

        INSERT INTO public.judgements (id, status)
        VALUES (p_request_id, 'awaiting_evidence');

        -- Send notifications concurrently via pg_net (async)
        -- 1. Notify Referee (assigned)
        PERFORM public.notify_event(
            v_matched_referee_id,
            'notification_task_assigned_referee',
            ARRAY[v_task.title]::text[],
            jsonb_build_object('route', '/tasks/' || v_request.task_id)
        );

        -- 2. Notify Tasker (matched/found)
        PERFORM public.notify_event(
            v_task.tasker_id,
            'notification_request_matched_tasker',
            ARRAY[v_task.title]::text[],
            jsonb_build_object('route', '/tasks/' || v_request.task_id)
        );

        RETURN json_build_object(
            'success', true,
            'matched', true,
            'referee_id', v_matched_referee_id,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    ELSE
        RETURN json_build_object(
            'success', true,
            'matched', false,
            'message', 'No suitable referee found',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.settle_evidence_timeout()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_matching_strategy public.matching_strategy;
    v_cost integer;
BEGIN
    -- Get task and user details
    SELECT t.tasker_id, trr.matched_referee_id, trr.task_id, t.title, trr.matching_strategy
    INTO v_tasker_id, v_referee_id, v_task_id, v_task_title, v_matching_strategy
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RAISE WARNING 'settle_evidence_timeout: request not found for judgement %', NEW.id;
        RETURN NEW;
    END IF;

    -- Determine point cost
    v_cost := public.get_point_for_matching_strategy(v_matching_strategy);

    -- Settle: consume locked points from tasker
    PERFORM public.consume_points(
        v_tasker_id,
        v_cost,
        'matching_settled'::public.point_reason,
        'Evidence timeout (judgement ' || NEW.id || ')',
        NEW.id
    );

    -- Grant reward to referee
    PERFORM public.grant_reward(
        v_referee_id,
        v_cost,
        'evidence_timeout'::public.reward_reason,
        'Evidence timeout (judgement ' || NEW.id || ')',
        NEW.id
    );

    -- Auto-set is_evidence_timeout_confirmed to close the request for referee side
    -- This triggers on_judgement_confirmed_close_request → request closes
    UPDATE public.judgements
    SET is_evidence_timeout_confirmed = true
    WHERE id = NEW.id;

    -- Notify tasker: evidence timed out
    PERFORM public.notify_event(
        v_tasker_id,
        'notification_evidence_timeout_tasker',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    -- Notify referee: reward granted
    PERFORM public.notify_event(
        v_referee_id,
        'notification_evidence_timeout_referee',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$function$
;


