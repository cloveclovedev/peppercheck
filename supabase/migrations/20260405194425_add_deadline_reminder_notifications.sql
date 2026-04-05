
  create table "public"."notification_sent_log" (
    "id" uuid not null default gen_random_uuid(),
    "judgement_id" uuid not null,
    "notification_key" text not null,
    "reminder_minutes" integer not null,
    "sent_at" timestamp with time zone not null default now()
      );


alter table "public"."notification_sent_log" enable row level security;


  create table "public"."notification_settings" (
    "user_id" uuid not null,
    "evidence_reminder_minutes" integer[] default '{10}'::integer[],
    "judgement_reminder_minutes" integer[] default '{10}'::integer[],
    "auto_confirm_reminder_minutes" integer[],
    "evidence_reminder_even_if_submitted" boolean not null default false,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."notification_settings" enable row level security;

CREATE UNIQUE INDEX idx_notification_sent_log_unique ON public.notification_sent_log USING btree (judgement_id, notification_key, reminder_minutes);

CREATE UNIQUE INDEX notification_sent_log_pkey ON public.notification_sent_log USING btree (id);

CREATE UNIQUE INDEX notification_settings_pkey ON public.notification_settings USING btree (user_id);

alter table "public"."notification_sent_log" add constraint "notification_sent_log_pkey" PRIMARY KEY using index "notification_sent_log_pkey";

alter table "public"."notification_settings" add constraint "notification_settings_pkey" PRIMARY KEY using index "notification_settings_pkey";

alter table "public"."notification_sent_log" add constraint "notification_sent_log_judgement_id_fkey" FOREIGN KEY (judgement_id) REFERENCES public.judgements(id) ON DELETE CASCADE not valid;

alter table "public"."notification_sent_log" validate constraint "notification_sent_log_judgement_id_fkey";

alter table "public"."notification_settings" add constraint "notification_settings_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."notification_settings" validate constraint "notification_settings_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.detect_auto_confirm_deadline_warnings()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_now timestamptz;
    v_count integer := 0;
    v_rec record;
BEGIN
    v_now := NOW();

    FOR v_rec IN
        SELECT
            j.id AS judgement_id,
            t.tasker_id AS user_id,
            t.id AS task_id,
            t.title AS task_title,
            t.due_date + INTERVAL '3 days' AS deadline,
            rm.reminder_minutes,
            p.timezone AS user_timezone
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        JOIN public.notification_settings ns ON ns.user_id = t.tasker_id
        JOIN public.profiles p ON p.id = t.tasker_id
        CROSS JOIN LATERAL unnest(ns.auto_confirm_reminder_minutes) AS rm(reminder_minutes)
        LEFT JOIN public.notification_sent_log nsl ON
            nsl.judgement_id = j.id
            AND nsl.notification_key = 'notification_auto_confirm_deadline_warning_tasker'
            AND nsl.reminder_minutes = rm.reminder_minutes
        WHERE j.is_confirmed = false
            AND j.status IN ('approved', 'rejected', 'review_timeout', 'evidence_timeout')
            AND t.due_date IS NOT NULL
            AND v_now >= (t.due_date + INTERVAL '3 days') - (rm.reminder_minutes || ' minutes')::interval
            AND v_now <= t.due_date + INTERVAL '3 days'
            AND nsl.id IS NULL
    LOOP
        PERFORM public.send_deadline_reminder(
            v_rec.judgement_id,
            v_rec.user_id,
            'notification_auto_confirm_deadline_warning_tasker',
            v_rec.reminder_minutes,
            v_rec.deadline,
            v_rec.task_id,
            v_rec.task_title,
            v_rec.user_timezone
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'reminder_count', v_count,
        'processed_at', v_now
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_evidence_deadline_warnings()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_now timestamptz;
    v_count integer := 0;
    v_rec record;
BEGIN
    v_now := NOW();

    FOR v_rec IN
        SELECT
            j.id AS judgement_id,
            t.tasker_id AS user_id,
            t.id AS task_id,
            t.title AS task_title,
            t.due_date AS deadline,
            rm.reminder_minutes,
            p.timezone AS user_timezone
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        LEFT JOIN public.task_evidences te ON t.id = te.task_id
        JOIN public.notification_settings ns ON ns.user_id = t.tasker_id
        JOIN public.profiles p ON p.id = t.tasker_id
        CROSS JOIN LATERAL unnest(ns.evidence_reminder_minutes) AS rm(reminder_minutes)
        LEFT JOIN public.notification_sent_log nsl ON
            nsl.judgement_id = j.id
            AND nsl.notification_key = 'notification_evidence_deadline_warning_tasker'
            AND nsl.reminder_minutes = rm.reminder_minutes
        WHERE j.status = 'awaiting_evidence'
            AND te.id IS NULL
            AND t.due_date IS NOT NULL
            AND v_now >= t.due_date - (rm.reminder_minutes || ' minutes')::interval
            AND v_now <= t.due_date
            AND nsl.id IS NULL
    LOOP
        PERFORM public.send_deadline_reminder(
            v_rec.judgement_id,
            v_rec.user_id,
            'notification_evidence_deadline_warning_tasker',
            v_rec.reminder_minutes,
            v_rec.deadline,
            v_rec.task_id,
            v_rec.task_title,
            v_rec.user_timezone
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'reminder_count', v_count,
        'processed_at', v_now
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_judgement_deadline_warnings()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_now timestamptz;
    v_count integer := 0;
    v_rec record;
BEGIN
    v_now := NOW();

    FOR v_rec IN
        SELECT
            j.id AS judgement_id,
            trr.matched_referee_id AS user_id,
            t.id AS task_id,
            t.title AS task_title,
            t.due_date + INTERVAL '3 hours' AS deadline,
            rm.reminder_minutes,
            p.timezone AS user_timezone
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        JOIN public.notification_settings ns ON ns.user_id = trr.matched_referee_id
        JOIN public.profiles p ON p.id = trr.matched_referee_id
        CROSS JOIN LATERAL unnest(ns.judgement_reminder_minutes) AS rm(reminder_minutes)
        LEFT JOIN public.notification_sent_log nsl ON
            nsl.judgement_id = j.id
            AND nsl.notification_key = 'notification_judgement_deadline_warning_referee'
            AND nsl.reminder_minutes = rm.reminder_minutes
        WHERE j.status = 'in_review'
            AND t.due_date IS NOT NULL
            AND v_now >= (t.due_date + INTERVAL '3 hours') - (rm.reminder_minutes || ' minutes')::interval
            AND v_now <= t.due_date + INTERVAL '3 hours'
            AND nsl.id IS NULL
    LOOP
        PERFORM public.send_deadline_reminder(
            v_rec.judgement_id,
            v_rec.user_id,
            'notification_judgement_deadline_warning_referee',
            v_rec.reminder_minutes,
            v_rec.deadline,
            v_rec.task_id,
            v_rec.task_title,
            v_rec.user_timezone
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'reminder_count', v_count,
        'processed_at', v_now
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.send_deadline_reminder(p_judgement_id uuid, p_user_id uuid, p_notification_key text, p_reminder_minutes integer, p_deadline timestamp with time zone, p_task_id uuid, p_task_title text, p_user_timezone text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_row_count integer;
    v_formatted_time text;
BEGIN
    -- Idempotency: attempt insert, skip if already sent
    INSERT INTO public.notification_sent_log (judgement_id, notification_key, reminder_minutes)
    VALUES (p_judgement_id, p_notification_key, p_reminder_minutes)
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    IF v_row_count = 0 THEN
        RETURN;
    END IF;

    -- Format deadline time in user's timezone
    v_formatted_time := TO_CHAR(
        p_deadline AT TIME ZONE COALESCE(p_user_timezone, 'UTC'),
        'HH24:MI'
    );

    -- Dispatch notification via notify_event
    PERFORM public.notify_event(
        p_user_id,
        p_notification_key,
        ARRAY[p_task_title, v_formatted_time],
        jsonb_build_object('task_id', p_task_id)
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_initial_grant integer;
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);

  INSERT INTO public.notification_settings (user_id) VALUES (NEW.id);

  INSERT INTO public.user_ratings (user_id)
  VALUES (NEW.id);

  INSERT INTO public.point_wallets (user_id)
  VALUES (NEW.id);

  -- Create trial point wallet with initial grant from config
  SELECT initial_grant_amount INTO v_initial_grant
  FROM public.trial_point_config
  WHERE id = true;

  v_initial_grant := COALESCE(v_initial_grant, 0);

  IF v_initial_grant > 0 THEN
    INSERT INTO public.trial_point_wallets (user_id, balance)
    VALUES (NEW.id, v_initial_grant);

    INSERT INTO public.trial_point_ledger (user_id, amount, reason, description)
    VALUES (NEW.id, v_initial_grant, 'initial_grant'::public.trial_point_reason, 'Trial points granted on registration');
  END IF;

  RETURN NEW;
END;
$function$
;

grant delete on table "public"."notification_sent_log" to "anon";

grant insert on table "public"."notification_sent_log" to "anon";

grant references on table "public"."notification_sent_log" to "anon";

grant select on table "public"."notification_sent_log" to "anon";

grant trigger on table "public"."notification_sent_log" to "anon";

grant truncate on table "public"."notification_sent_log" to "anon";

grant update on table "public"."notification_sent_log" to "anon";

grant delete on table "public"."notification_sent_log" to "authenticated";

grant insert on table "public"."notification_sent_log" to "authenticated";

grant references on table "public"."notification_sent_log" to "authenticated";

grant select on table "public"."notification_sent_log" to "authenticated";

grant trigger on table "public"."notification_sent_log" to "authenticated";

grant truncate on table "public"."notification_sent_log" to "authenticated";

grant update on table "public"."notification_sent_log" to "authenticated";

grant delete on table "public"."notification_sent_log" to "service_role";

grant insert on table "public"."notification_sent_log" to "service_role";

grant references on table "public"."notification_sent_log" to "service_role";

grant select on table "public"."notification_sent_log" to "service_role";

grant trigger on table "public"."notification_sent_log" to "service_role";

grant truncate on table "public"."notification_sent_log" to "service_role";

grant update on table "public"."notification_sent_log" to "service_role";

grant delete on table "public"."notification_settings" to "anon";

grant insert on table "public"."notification_settings" to "anon";

grant references on table "public"."notification_settings" to "anon";

grant select on table "public"."notification_settings" to "anon";

grant trigger on table "public"."notification_settings" to "anon";

grant truncate on table "public"."notification_settings" to "anon";

grant update on table "public"."notification_settings" to "anon";

grant delete on table "public"."notification_settings" to "authenticated";

grant insert on table "public"."notification_settings" to "authenticated";

grant references on table "public"."notification_settings" to "authenticated";

grant select on table "public"."notification_settings" to "authenticated";

grant trigger on table "public"."notification_settings" to "authenticated";

grant truncate on table "public"."notification_settings" to "authenticated";

grant update on table "public"."notification_settings" to "authenticated";

grant delete on table "public"."notification_settings" to "service_role";

grant insert on table "public"."notification_settings" to "service_role";

grant references on table "public"."notification_settings" to "service_role";

grant select on table "public"."notification_settings" to "service_role";

grant trigger on table "public"."notification_settings" to "service_role";

grant truncate on table "public"."notification_settings" to "service_role";

grant update on table "public"."notification_settings" to "service_role";


  create policy "notification_settings: users can read own settings"
  on "public"."notification_settings"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "notification_settings: users can update own settings"
  on "public"."notification_settings"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));

-- DML, not detected by schema diff
SELECT cron.schedule(
    'detect-evidence-deadline-warnings',
    '* * * * *',
    $$SELECT public.detect_evidence_deadline_warnings()$$
);

SELECT cron.schedule(
    'detect-judgement-deadline-warnings',
    '* * * * *',
    $$SELECT public.detect_judgement_deadline_warnings()$$
);

SELECT cron.schedule(
    'detect-auto-confirm-deadline-warnings',
    '* * * * *',
    $$SELECT public.detect_auto_confirm_deadline_warnings()$$
);

-- DML, not detected by schema diff: backfill existing users
INSERT INTO public.notification_settings (user_id)
SELECT id FROM auth.users
ON CONFLICT DO NOTHING;

