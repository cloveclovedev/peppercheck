begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- ============================================================
-- Setup: create two test users (tasker + referee)
-- ============================================================
INSERT INTO auth.users (id, email) VALUES
    ('a1111111-1111-1111-1111-111111111111', 'tasker@test.com'),
    ('b2222222-2222-2222-2222-222222222222', 'referee@test.com');

-- Update tasker timezone
UPDATE public.profiles SET timezone = 'Asia/Tokyo'
WHERE id = 'a1111111-1111-1111-1111-111111111111';

-- ============================================================
-- Test 1: notification_settings auto-created on user creation
-- ============================================================
SELECT is(
    (SELECT evidence_reminder_minutes FROM public.notification_settings
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'),
    '{10}'::integer[],
    'notification_settings auto-created with default evidence_reminder_minutes = {10}'
);

-- ============================================================
-- Test 2: auto_confirm_reminder_minutes defaults to NULL (OFF)
-- ============================================================
SELECT is(
    (SELECT auto_confirm_reminder_minutes FROM public.notification_settings
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'),
    NULL::integer[],
    'auto_confirm_reminder_minutes defaults to NULL (OFF)'
);

-- ============================================================
-- Setup: create task + referee request + judgement approaching evidence deadline
-- due_date = now() + 5 minutes (inside 10-min reminder window)
-- ============================================================
INSERT INTO public.tasks (id, tasker_id, title, due_date, status) VALUES
    ('c3333333-3333-3333-3333-333333333333',
     'a1111111-1111-1111-1111-111111111111',
     'Test Task',
     NOW() + INTERVAL '5 minutes',
     'open');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id) VALUES
    ('d4444444-4444-4444-4444-444444444444',
     'c3333333-3333-3333-3333-333333333333',
     'standard',
     'matched',
     'b2222222-2222-2222-2222-222222222222');

INSERT INTO public.judgements (id, status) VALUES
    ('d4444444-4444-4444-4444-444444444444', 'awaiting_evidence');

-- ============================================================
-- Test 3: detect_evidence_deadline_warnings finds approaching deadline
-- ============================================================
SELECT lives_ok(
    $$SELECT public.detect_evidence_deadline_warnings()$$,
    'detect_evidence_deadline_warnings executes without error'
);

SELECT is(
    (SELECT count(*)::integer FROM public.notification_sent_log
     WHERE judgement_id = 'd4444444-4444-4444-4444-444444444444'
       AND notification_key = 'notification_evidence_deadline_warning_tasker'
       AND reminder_minutes = 10),
    1,
    'Evidence deadline warning sent and logged (reminder_minutes=10)'
);

-- ============================================================
-- Test 4: Idempotency — running again does not create duplicate
-- ============================================================
SELECT lives_ok(
    $$SELECT public.detect_evidence_deadline_warnings()$$,
    'detect_evidence_deadline_warnings is idempotent'
);

SELECT is(
    (SELECT count(*)::integer FROM public.notification_sent_log
     WHERE judgement_id = 'd4444444-4444-4444-4444-444444444444'
       AND notification_key = 'notification_evidence_deadline_warning_tasker'),
    1,
    'Still only 1 sent_log record after second run (idempotent)'
);

-- ============================================================
-- Test 5: Multiple reminders — {60, 10} creates separate records
-- ============================================================
UPDATE public.notification_settings
SET evidence_reminder_minutes = '{60, 10}'
WHERE user_id = 'a1111111-1111-1111-1111-111111111111';

-- Adjust due_date so both 60-min and 10-min windows are active
UPDATE public.tasks SET due_date = NOW() + INTERVAL '5 minutes'
WHERE id = 'c3333333-3333-3333-3333-333333333333';

-- Clear previous log to test fresh
DELETE FROM public.notification_sent_log
WHERE judgement_id = 'd4444444-4444-4444-4444-444444444444';

SELECT lives_ok(
    $$SELECT public.detect_evidence_deadline_warnings()$$,
    'detect_evidence_deadline_warnings handles multiple reminder times'
);

SELECT is(
    (SELECT count(*)::integer FROM public.notification_sent_log
     WHERE judgement_id = 'd4444444-4444-4444-4444-444444444444'
       AND notification_key = 'notification_evidence_deadline_warning_tasker'),
    2,
    'Two sent_log records created for {60, 10} reminder setting'
);

-- ============================================================
-- Test 6: NULL setting (OFF) — no reminder fires
-- ============================================================
-- Auto-confirm reminders are NULL by default, so detection should produce 0 records
-- First set judgement to a terminal state for auto-confirm detection
UPDATE public.judgements SET status = 'approved', is_confirmed = false
WHERE id = 'd4444444-4444-4444-4444-444444444444';

UPDATE public.tasks SET due_date = NOW() - INTERVAL '2 days 23 hours 55 minutes'
WHERE id = 'c3333333-3333-3333-3333-333333333333';

SELECT lives_ok(
    $$SELECT public.detect_auto_confirm_deadline_warnings()$$,
    'detect_auto_confirm_deadline_warnings executes with NULL setting'
);

SELECT is(
    (SELECT count(*)::integer FROM public.notification_sent_log
     WHERE notification_key = 'notification_auto_confirm_deadline_warning_tasker'),
    0,
    'No auto-confirm reminder sent when setting is NULL (OFF)'
);

select * from finish();
rollback;
