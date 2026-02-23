# Auto Confirm Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically confirm judgements when the tasker doesn't act within 3 days after the due date, ensuring tasks don't hang indefinitely and referees receive timely rewards.

**Architecture:** A pg_cron job runs hourly, calling `detect_auto_confirms()` which finds eligible judgements and processes them (settlement for approved/rejected, flag-only for timeouts). A unified notification trigger fires on `is_confirmed` change and branches on `is_auto_confirmed` to send appropriate notifications.

**Tech Stack:** PostgreSQL (pg_cron, plpgsql), Supabase Edge Functions (Deno/TypeScript), Flutter (slang i18n), Android (strings.xml), iOS (Localizable.strings)

**Design Doc:** `docs/plans/2026-02-22-auto-confirm-design.md`

---

### Task 1: Add `is_auto_confirmed` column to judgements table

**Files:**
- Modify: `supabase/schemas/judgement/tables/judgements.sql`

**Step 1: Add the column**

Add `is_auto_confirmed boolean DEFAULT false NOT NULL` after `is_confirmed`:

```sql
    -- Workflow Flags
    is_confirmed boolean DEFAULT false,
    is_auto_confirmed boolean DEFAULT false NOT NULL,
    reopen_count smallint DEFAULT 0 NOT NULL,
```

**Step 2: Commit**

```bash
git add supabase/schemas/judgement/tables/judgements.sql
git commit -m "feat: add is_auto_confirmed column to judgements table (#72)"
```

---

### Task 2: Create `detect_auto_confirms()` function

**Files:**
- Create: `supabase/schemas/judgement/functions/detect_auto_confirms.sql`
- Modify: `supabase/config.toml` (register new schema file)

**Step 1: Create the function**

Create `supabase/schemas/judgement/functions/detect_auto_confirms.sql`:

```sql
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
```

**Step 2: Register in config.toml**

Add the following line in `supabase/config.toml` after line 136 (after `detect_review_timeouts.sql`):

```toml
  "./schemas/judgement/functions/detect_auto_confirms.sql",
```

**Step 3: Commit**

```bash
git add supabase/schemas/judgement/functions/detect_auto_confirms.sql supabase/config.toml
git commit -m "feat: add detect_auto_confirms() function (#72)"
```

---

### Task 3: Create notification trigger `on_judgement_confirmed_notify`

**Files:**
- Create: `supabase/schemas/judgement/triggers/on_judgement_confirmed_notify.sql`
- Modify: `supabase/config.toml` (register new schema file)

**Step 1: Create the trigger**

Create `supabase/schemas/judgement/triggers/on_judgement_confirmed_notify.sql`:

```sql
-- Function + Trigger: Send notification when judgement is confirmed
-- Branches on is_auto_confirmed to determine notification type
CREATE OR REPLACE FUNCTION public.notify_judgement_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
BEGIN
    -- Get task and user details
    SELECT t.tasker_id, trr.matched_referee_id, trr.task_id, t.title
    INTO v_tasker_id, v_referee_id, v_task_id, v_task_title
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RAISE WARNING 'notify_judgement_confirmed: request not found for judgement %', NEW.id;
        RETURN NEW;
    END IF;

    IF NEW.is_auto_confirmed THEN
        -- Auto-confirm: notify both tasker and referee
        PERFORM public.notify_event(
            v_tasker_id,
            'notification_auto_confirm_tasker',
            ARRAY[v_task_title],
            jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
        );

        PERFORM public.notify_event(
            v_referee_id,
            'notification_auto_confirm_referee',
            ARRAY[v_task_title],
            jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
        );
    -- ELSE: manual confirm notification (future implementation)
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_judgement_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_judgement_confirmed_notify
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND OLD.is_confirmed = false)
    EXECUTE FUNCTION public.notify_judgement_confirmed();

COMMENT ON TRIGGER on_judgement_confirmed_notify ON public.judgements IS 'Sends notification when judgement is confirmed. Branches on is_auto_confirmed for auto-confirm vs manual confirm notifications.';
```

**Step 2: Register in config.toml**

Add the following line in `supabase/config.toml` after the last judgement trigger entry (after `on_judgements_status_changed.sql`, line 177):

```toml
  "./schemas/judgement/triggers/on_judgement_confirmed_notify.sql",
```

**Step 3: Commit**

```bash
git add supabase/schemas/judgement/triggers/on_judgement_confirmed_notify.sql supabase/config.toml
git commit -m "feat: add unified judgement confirmed notification trigger (#72)"
```

---

### Task 4: Create cron job

**Files:**
- Create: `supabase/schemas/judgement/cron/cron_detect_auto_confirm.sql`

**Step 1: Create the cron schedule**

Create `supabase/schemas/judgement/cron/cron_detect_auto_confirm.sql`:

```sql
-- Schedule auto-confirm detection every hour
-- pg_cron extension is enabled in extensions.sql
SELECT cron.schedule(
    'detect-auto-confirms',
    '0 * * * *',
    $$SELECT public.detect_auto_confirms()$$
);
```

Note: cron files are DML, not captured by `db diff`. They must be manually appended to the migration file.

**Step 2: Commit**

```bash
git add supabase/schemas/judgement/cron/cron_detect_auto_confirm.sql
git commit -m "feat: add pg_cron job for auto-confirm detection (#72)"
```

---

### Task 5: Add notification strings

**Files:**
- Modify: `peppercheck_flutter/android/app/src/main/res/values/strings.xml` (English)
- Modify: `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml` (Japanese)
- Modify: `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings` (English)
- Modify: `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings` (Japanese)
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json` (Flutter slang)
- Modify: `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`

**Step 1: Add Android English strings**

Add before the closing `</resources>` tag in `peppercheck_flutter/android/app/src/main/res/values/strings.xml`:

```xml
    <string name="notification_auto_confirm_tasker_title">Auto Confirmed</string>
    <string name="notification_auto_confirm_tasker_body">Your task "%1$s" has been automatically confirmed.</string>
    <string name="notification_auto_confirm_referee_title">Review Confirmed</string>
    <string name="notification_auto_confirm_referee_body">Your review for task "%1$s" has been confirmed.</string>
```

**Step 2: Add Android Japanese strings**

Add before the closing `</resources>` tag in `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`:

```xml
    <string name="notification_auto_confirm_tasker_title">自動確認</string>
    <string name="notification_auto_confirm_tasker_body">タスク「%1$s」の評価が自動的に確認されました。</string>
    <string name="notification_auto_confirm_referee_title">評価確認</string>
    <string name="notification_auto_confirm_referee_body">タスク「%1$s」の評価が確認されました。</string>
```

**Step 3: Add iOS English strings**

Add at the end of `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings`:

```
"notification_auto_confirm_tasker_title" = "Auto Confirmed";
"notification_auto_confirm_tasker_body" = "Your task \"%@\" has been automatically confirmed.";
"notification_auto_confirm_referee_title" = "Review Confirmed";
"notification_auto_confirm_referee_body" = "Your review for task \"%@\" has been confirmed.";
```

**Step 4: Add iOS Japanese strings**

Add at the end of `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings`:

```
"notification_auto_confirm_tasker_title" = "自動確認";
"notification_auto_confirm_tasker_body" = "タスク「%@」の評価が自動的に確認されました。";
"notification_auto_confirm_referee_title" = "評価確認";
"notification_auto_confirm_referee_body" = "タスク「%@」の評価が確認されました。";
```

**Step 5: Add Flutter i18n strings**

Add to the `"notification"` object in `peppercheck_flutter/assets/i18n/ja.i18n.json`:

```json
    "auto_confirm_tasker_title": "自動確認",
    "auto_confirm_tasker_body": "タスク「${taskTitle}」の評価が自動的に確認されました。",
    "auto_confirm_referee_title": "評価確認",
    "auto_confirm_referee_body": "タスク「${taskTitle}」の評価が確認されました。",
```

**Step 6: Add resolver entries**

Add the following cases in `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`, in the `_resolveKey` switch statement before the `default` case:

```dart
    case 'notification_auto_confirm_tasker_title':
      return t.notification.auto_confirm_tasker_title;
    case 'notification_auto_confirm_tasker_body':
      return t.notification.auto_confirm_tasker_body(taskTitle: taskTitle);
    case 'notification_auto_confirm_referee_title':
      return t.notification.auto_confirm_referee_title;
    case 'notification_auto_confirm_referee_body':
      return t.notification.auto_confirm_referee_body(taskTitle: taskTitle);
```

**Step 7: Run slang code generation**

```bash
cd peppercheck_flutter && dart run slang
```

Expected: Slang regenerates `strings.g.dart` with the new notification keys.

**Step 8: Commit**

```bash
git add peppercheck_flutter/android/app/src/main/res/values/strings.xml \
  peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml \
  peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings \
  peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings \
  peppercheck_flutter/assets/i18n/ja.i18n.json \
  peppercheck_flutter/lib/gen/slang/ \
  peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart
git commit -m "feat: add auto-confirm notification strings (#72)"
```

---

### Task 6: Write tests

**Files:**
- Create: `supabase/tests/test_auto_confirm.sql`

**Step 1: Write the test file**

Create `supabase/tests/test_auto_confirm.sql`:

```sql
-- =============================================================================
-- Test: Auto Confirm
--
-- Usage:
--   docker cp supabase/tests/test_auto_confirm.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_auto_confirm.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Auto Confirm'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Cleaning up existing test data...'

DELETE FROM public.rating_histories WHERE judgement_id IN (
  SELECT id FROM public.judgements WHERE id IN (
    SELECT id FROM public.task_referee_requests WHERE task_id IN (
      SELECT id FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
    )
  )
);
DELETE FROM public.judgements WHERE id IN (
  SELECT id FROM public.task_referee_requests WHERE task_id IN (
    SELECT id FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
  )
);
DELETE FROM public.task_referee_requests WHERE task_id IN (
  SELECT id FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
);
DELETE FROM public.tasks WHERE tasker_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.reward_ledger WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.point_ledger WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.reward_wallets WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM public.point_wallets WHERE user_id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
DELETE FROM auth.users WHERE id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

\echo '[Setup] Creating test users...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Setting point wallet...'

UPDATE public.point_wallets
SET balance = 10, locked = 0
WHERE user_id = '11111111-1111-1111-1111-111111111111';


-- ===== Test 1: Auto-confirm approved judgement =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Auto-confirm approved judgement (settlement + rating)'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Approved Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for approved test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

SELECT public.detect_auto_confirms();

DO $$
BEGIN
  -- Verify is_confirmed and is_auto_confirmed flags
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 1 FAILED: is_confirmed should be true';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 1 FAILED: is_auto_confirmed should be true';

  -- Verify settlement
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 1 FAILED: tasker balance should be 9 after settlement';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 1 FAILED: tasker locked should be 0 after settlement';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 1 FAILED: referee reward should be 1';

  -- Verify auto-positive rating
  ASSERT (SELECT is_positive FROM public.rating_histories
    WHERE judgement_id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND rating_type = 'referee') = true,
    'Test 1 FAILED: should have auto-positive rating';
  ASSERT (SELECT rater_id FROM public.rating_histories
    WHERE judgement_id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND rating_type = 'referee') = '11111111-1111-1111-1111-111111111111',
    'Test 1 FAILED: rater should be the tasker';

  -- Verify request and task closed
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 1 FAILED: request should be closed';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 1 FAILED: task should be closed';

  RAISE NOTICE 'Test 1 PASSED: approved judgement auto-confirmed with settlement + rating';
END $$;


-- ===== Test 2: Auto-confirm rejected judgement =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Auto-confirm rejected judgement'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Rejected Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for rejected test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'rejected');

SELECT public.detect_auto_confirms();

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 2 FAILED: is_confirmed should be true';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-bbbb-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 2 FAILED: is_auto_confirmed should be true';
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 8,
    'Test 2 FAILED: tasker balance should be 8 after second settlement';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 2,
    'Test 2 FAILED: referee reward should be 2';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 2 FAILED: task should be closed';

  RAISE NOTICE 'Test 2 PASSED: rejected judgement auto-confirmed with settlement';
END $$;


-- ===== Test 3: Auto-confirm review_timeout judgement (no settlement) =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Auto-confirm review_timeout (no settlement)'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Review Timeout Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for review timeout test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa', 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'closed', '22222222-2222-2222-2222-222222222222', now());

-- review_timeout: settlement already done (points unlocked, request closed, negative rating)
-- Simulate post-settlement state
INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa', 'review_timeout');

-- Unlock points to simulate settle_review_timeout already ran
SELECT public.unlock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_unlock'::public.point_reason, 'Simulated review timeout unlock');

-- Record current balances before auto-confirm
DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 3 FAILED: is_confirmed should be true';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-dddd-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 3 FAILED: is_auto_confirmed should be true';

  -- No additional settlement should occur
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 3 FAILED: tasker balance should not change (already settled)';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 3 FAILED: referee reward should not change (already settled)';

  ASSERT (SELECT status FROM public.tasks WHERE id = 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 3 FAILED: task should be closed';

  RAISE NOTICE 'Test 3 PASSED: review_timeout auto-confirmed without additional settlement';
END $$;


-- ===== Test 4: Auto-confirm evidence_timeout judgement (no settlement) =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Auto-confirm evidence_timeout (no settlement)'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Evidence Timeout Task', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for evidence timeout test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-eeee-aaaa-aaaa-aaaaaaaaaaaa', 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'closed', '22222222-2222-2222-2222-222222222222', now());

-- evidence_timeout: settlement already done (points consumed, reward granted, request closed)
-- Simulate post-settlement state
INSERT INTO public.judgements (id, status, is_evidence_timeout_confirmed)
VALUES ('cccccccc-eeee-aaaa-aaaa-aaaaaaaaaaaa', 'evidence_timeout', true);

-- Consume points to simulate settle_evidence_timeout already ran
SELECT public.consume_points('11111111-1111-1111-1111-111111111111', 1, 'matching_settled'::public.point_reason, 'Simulated evidence timeout consume');

-- Grant reward to simulate settle_evidence_timeout already ran
SELECT public.grant_reward('22222222-2222-2222-2222-222222222222', 1, 'evidence_timeout'::public.reward_reason, 'Simulated evidence timeout reward');

DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-eeee-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 4 FAILED: is_confirmed should be true';

  -- No additional settlement
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 4 FAILED: tasker balance should not change';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 4 FAILED: referee reward should not change';

  ASSERT (SELECT status FROM public.tasks WHERE id = 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 4 FAILED: task should be closed';

  RAISE NOTICE 'Test 4 PASSED: evidence_timeout auto-confirmed without additional settlement';
END $$;


-- ===== Test 5: Does NOT auto-confirm within grace period =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Does NOT auto-confirm within grace period'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('ffffffff-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Within Grace Task', 'Desc', 'Criteria', now() - interval '2 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for grace period test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa', 'ffffffff-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

SELECT public.detect_auto_confirms();

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 5 FAILED: is_confirmed should be false (within grace period)';
  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-ffff-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 5 FAILED: is_auto_confirmed should be false (within grace period)';

  RAISE NOTICE 'Test 5 PASSED: judgement within grace period not auto-confirmed';
END $$;


-- ===== Test 6: Idempotency — running again does not double-process =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Idempotency'
\echo '=========================================='

DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 6 FAILED: balance should not change on re-run';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 6 FAILED: reward should not change on re-run';

  RAISE NOTICE 'Test 6 PASSED: idempotency prevents double-processing';
END $$;


-- ===== Test 7: Already manually confirmed judgements are skipped =====
\echo ''
\echo '=========================================='
\echo ' Test 7: Already confirmed judgements are skipped'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Already Confirmed', 'Desc', 'Criteria', now() - interval '4 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for already confirmed test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-1111-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status, is_confirmed)
VALUES ('cccccccc-1111-aaaa-aaaa-aaaaaaaaaaaa', 'approved', true);

-- Manually settle (simulating manual confirm was done)
SELECT public.consume_points('11111111-1111-1111-1111-111111111111', 1, 'matching_settled'::public.point_reason, 'Manual confirm');
SELECT public.grant_reward('22222222-2222-2222-2222-222222222222', 1, 'review_completed'::public.reward_reason, 'Manual confirm');

DO $$
DECLARE
  v_balance_before int;
  v_reward_before int;
BEGIN
  SELECT balance INTO v_balance_before FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111';
  SELECT balance INTO v_reward_before FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';

  PERFORM public.detect_auto_confirms();

  ASSERT (SELECT is_auto_confirmed FROM public.judgements WHERE id = 'cccccccc-1111-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 7 FAILED: is_auto_confirmed should remain false';
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = v_balance_before,
    'Test 7 FAILED: balance should not change for already confirmed';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = v_reward_before,
    'Test 7 FAILED: reward should not change for already confirmed';

  RAISE NOTICE 'Test 7 PASSED: already confirmed judgements are skipped';
END $$;


-- ===== Cleanup =====
\echo ''
\echo '=========================================='
\echo ' Cleanup'
\echo '=========================================='

ROLLBACK;

\echo 'All test data rolled back.'
\echo ''
\echo '=========================================='
\echo ' All tests complete!'
\echo '=========================================='
```

**Step 2: Commit**

```bash
git add supabase/tests/test_auto_confirm.sql
git commit -m "test: add auto-confirm unit tests (#72)"
```

---

### Task 7: Generate migration and verify

**Step 1: Reset local DB and generate migration**

```bash
supabase db diff -f add_auto_confirm
```

**Step 2: Review generated migration**

Verify the migration includes:
- `ALTER TABLE public.judgements ADD COLUMN is_auto_confirmed boolean DEFAULT false NOT NULL`
- `CREATE OR REPLACE FUNCTION public.detect_auto_confirms()`
- `CREATE OR REPLACE FUNCTION public.notify_judgement_confirmed()`
- `CREATE OR REPLACE TRIGGER on_judgement_confirmed_notify`

**Step 3: Append DML (cron job)**

Manually append the cron schedule to the generated migration file (DML is not captured by `db diff`):

```sql
-- DML, not detected by schema diff
SELECT cron.schedule(
    'detect-auto-confirms',
    '0 * * * *',
    $$SELECT public.detect_auto_confirms()$$
);
```

**Step 4: Full reset and test**

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

**Step 5: Run new test**

```bash
docker cp supabase/tests/test_auto_confirm.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_auto_confirm.sql
```

Expected: All 7 tests pass.

**Step 6: Run all existing tests (regression)**

```bash
for f in supabase/tests/test_*.sql; do
  echo "=== Running $f ==="
  docker cp "$f" supabase_db_supabase:/tmp/ && \
  docker exec supabase_db_supabase psql -U postgres -f "/tmp/$(basename "$f")"
  echo ""
done
```

Expected: All existing tests pass without regression.

**Step 7: Commit migration**

```bash
git add supabase/migrations/
git commit -m "feat: add auto-confirm migration (#72)"
```
