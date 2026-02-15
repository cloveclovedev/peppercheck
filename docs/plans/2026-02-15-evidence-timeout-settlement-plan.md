# Evidence Timeout Settlement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically detect evidence timeouts, settle points (consume from tasker, reward referee), close the referee request, and provide a tasker confirm function to close the task.

**Architecture:** When cron detects an evidence timeout (due_date passed, no evidence submitted), a trigger on the status change settles points and auto-closes the referee side. The tasker must explicitly confirm before the task closes. Task closure condition changes from "all requests closed" to "all judgements confirmed".

**Tech Stack:** PostgreSQL (plpgsql), pg_cron, Supabase CLI (`supabase db diff`, `supabase migration up`)

**Important workflow notes:**
- Schema files represent the **final desired state** only. No DROP statements.
- Migration files are auto-generated via `supabase db diff -f <name>`.
- After generating migration, apply with `supabase migration up` before testing.

---

### Task 1: Create the evidence timeout settlement trigger

**Files:**
- Create: `supabase/schemas/judgement/triggers/on_evidence_timeout_settle.sql`

**Step 1: Write the trigger function and trigger declaration**

This trigger fires when `judgements.status` changes to `evidence_timeout`. It settles points, grants reward, sets `is_evidence_timeout_confirmed = true` (cascading to request closure), and sends notifications.

```sql
-- Function + Trigger: Settle points and reward on evidence timeout
CREATE OR REPLACE FUNCTION public.settle_evidence_timeout() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_matching_strategy public.matching_strategy;
    v_cost integer;
BEGIN
    -- Only process when status changes TO evidence_timeout
    IF NEW.status != 'evidence_timeout' OR OLD.status = 'evidence_timeout' THEN
        RETURN NEW;
    END IF;

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
        'notification_evidence_timeout',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    -- Notify referee: reward granted
    PERFORM public.notify_event(
        v_referee_id,
        'notification_evidence_timeout_reward',
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.settle_evidence_timeout() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_evidence_timeout_settle
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.status = 'evidence_timeout' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.settle_evidence_timeout();

COMMENT ON TRIGGER on_evidence_timeout_settle ON public.judgements IS 'Settles points (consume from tasker, reward referee) and auto-closes referee side when evidence timeout is detected.';
```

**Step 2: Commit**

```bash
git add supabase/schemas/judgement/triggers/on_evidence_timeout_settle.sql
git commit -m "feat: add evidence timeout settlement trigger"
```

---

### Task 2: Create the tasker confirm function for evidence timeout

**Files:**
- Create: `supabase/schemas/judgement/functions/confirm_evidence_timeout.sql`

**Step 1: Write the function**

Allows the tasker to confirm/acknowledge an evidence timeout. Point settlement already happened via trigger — this only sets `is_confirmed = true`.

```sql
CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout(p_judgement_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
BEGIN
    -- Get judgement with task info
    SELECT j.id, j.status, j.is_confirmed, t.tasker_id
    INTO v_judgement
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;

    -- Validate caller is the tasker
    IF v_judgement.tasker_id != (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'Only the tasker can confirm an evidence timeout';
    END IF;

    -- Validate status
    IF v_judgement.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement must be in evidence_timeout status to confirm';
    END IF;

    -- Idempotency
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Confirm (triggers task closure check via on_all_judgements_confirmed_close_task)
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
END;
$$;

ALTER FUNCTION public.confirm_evidence_timeout(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_evidence_timeout(uuid) IS 'Allows tasker to confirm/acknowledge an evidence timeout. Points were already settled by the settle_evidence_timeout trigger. Sets is_confirmed = true which triggers task closure check.';
```

**Step 2: Commit**

```bash
git add supabase/schemas/judgement/functions/confirm_evidence_timeout.sql
git commit -m "feat: add confirm_evidence_timeout function for tasker acknowledgement"
```

---

### Task 3: Change task closure from request-based to judgement-based

**Files:**
- Delete: `supabase/schemas/task/triggers/on_all_requests_closed_close_task.sql`
- Create: `supabase/schemas/task/triggers/on_all_judgements_confirmed_close_task.sql`

**Step 1: Delete the old file and create the new one**

The new trigger fires on `judgements.is_confirmed` change instead of `task_referee_requests.status` change.

Delete `supabase/schemas/task/triggers/on_all_requests_closed_close_task.sql`.

Create `supabase/schemas/task/triggers/on_all_judgements_confirmed_close_task.sql`:

```sql
-- Function + Trigger: Close task when all judgements are confirmed
CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_task_id uuid;
BEGIN
    -- Get the task_id for this judgement
    SELECT trr.task_id INTO v_task_id
    FROM public.task_referee_requests trr
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Concurrency protection: lock the task row
    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    -- Check if all judgements for this task are confirmed
    IF NOT EXISTS (
        SELECT 1 FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        WHERE trr.task_id = v_task_id AND j.is_confirmed = false
    ) THEN
        UPDATE public.tasks
        SET status = 'closed'::public.task_status
        WHERE id = v_task_id;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.close_task_if_all_judgements_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_all_judgements_confirmed_close_task
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND OLD.is_confirmed = false)
    EXECUTE FUNCTION public.close_task_if_all_judgements_confirmed();

COMMENT ON TRIGGER on_all_judgements_confirmed_close_task ON public.judgements IS 'Closes the task when all judgements for that task have is_confirmed = true. Separates referee-side closure (request) from tasker-side closure (task).';
```

**Step 2: Commit**

```bash
git rm supabase/schemas/task/triggers/on_all_requests_closed_close_task.sql
git add supabase/schemas/task/triggers/on_all_judgements_confirmed_close_task.sql
git commit -m "refactor: change task closure from request-based to judgement-based"
```

---

### Task 4: Clean up obsolete code

**Files:**
- Delete: `supabase/schemas/evidence/functions/confirm_evidence_timeout.sql`
- Modify: `supabase/schemas/judgement/triggers/on_judgements_evidence_timeout_close_referee_request.sql`

**Step 1: Delete `confirm_evidence_timeout_from_referee()`**

No longer needed since settlement is automatic.

```bash
rm supabase/schemas/evidence/functions/confirm_evidence_timeout.sql
```

**Step 2: Update `handle_evidence_timeout_confirmed()` comments**

Update the file to clarify it's a no-op and why:

```sql
-- Function + Trigger: Handle evidence timeout confirmation
-- NOTE: Settlement is handled by settle_evidence_timeout() trigger on status change.
-- Request closure is handled by on_judgement_confirmed_close_request trigger.
-- This trigger is kept as a no-op for documentation purposes.
CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    IF NEW.is_evidence_timeout_confirmed = true
       AND OLD.is_evidence_timeout_confirmed = false
       AND NEW.status = 'evidence_timeout' THEN
        -- No-op: settlement handled by on_evidence_timeout_settle trigger.
        -- Request closure handled by on_judgement_confirmed_close_request trigger.
        NULL;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_evidence_timeout_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_judgements_evidence_timeout_confirmed
    AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
    FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmed();

COMMENT ON TRIGGER on_judgements_evidence_timeout_confirmed ON public.judgements IS 'No-op trigger. Settlement handled by on_evidence_timeout_settle. Request closure handled by on_judgement_confirmed_close_request.';
```

**Step 3: Commit**

```bash
git rm supabase/schemas/evidence/functions/confirm_evidence_timeout.sql
git add supabase/schemas/judgement/triggers/on_judgements_evidence_timeout_close_referee_request.sql
git commit -m "chore: remove obsolete confirm_evidence_timeout_from_referee, update trigger comments"
```

---

### Task 5: Schedule the cron job

**Files:**
- Create: `supabase/schemas/judgement/cron/cron_detect_evidence_timeout.sql`

**Step 1: Write the cron schedule**

```sql
-- Schedule evidence timeout detection every 5 minutes
-- pg_cron extension is enabled in extensions.sql
SELECT cron.schedule(
    'detect-evidence-timeouts',
    '*/5 * * * *',
    $$SELECT public.detect_and_handle_evidence_timeouts()$$
);
```

**Step 2: Commit**

```bash
mkdir -p supabase/schemas/judgement/cron
git add supabase/schemas/judgement/cron/cron_detect_evidence_timeout.sql
git commit -m "feat: schedule evidence timeout detection cron job (every 5 min)"
```

---

### Task 6: Generate migration and apply

**Step 1: Generate migration from schema diff**

```bash
supabase db diff -f add_evidence_timeout_settlement
```

This compares the current schema files against the database and generates a migration file with all necessary changes (CREATE, DROP, ALTER).

**Step 2: Review the generated migration**

Read the generated file in `supabase/migrations/` and verify it contains:
- New `settle_evidence_timeout()` function and trigger
- New `confirm_evidence_timeout()` function
- Drop of old `close_task_if_all_requests_closed()` + old trigger
- New `close_task_if_all_judgements_confirmed()` function and trigger
- Drop of `confirm_evidence_timeout_from_referee()` function
- Updated `handle_evidence_timeout_confirmed()` function
- Cron schedule

**Step 3: Apply migration**

```bash
supabase migration up
```

**Step 4: Commit**

```bash
git add supabase/migrations/*_add_evidence_timeout_settlement.sql
git commit -m "feat: add evidence timeout settlement migration"
```

---

### Task 7: Write tests

**Files:**
- Create: `supabase/tests/test_evidence_timeout_settlement.sql`

**Step 1: Write the test file**

Follow existing pattern from `supabase/tests/test_reward_system.sql`. Tests run inside a transaction and rollback.

```sql
-- =============================================================================
-- Test: Evidence Timeout Settlement
--
-- Usage:
--   docker cp supabase/tests/test_evidence_timeout_settlement.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_evidence_timeout_settlement.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Evidence Timeout Settlement'
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


-- ===== Test 1: Evidence timeout detection changes status =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Evidence timeout detection'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Timeout Task', 'Desc', 'Criteria', now() - interval '1 hour', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for timeout test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'awaiting_evidence');

SELECT public.detect_and_handle_evidence_timeouts();

DO $$
BEGIN
  ASSERT (SELECT status FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'evidence_timeout',
    'Test 1 FAILED: status should be evidence_timeout';
  RAISE NOTICE 'Test 1 PASSED: detection changes status to evidence_timeout';
END $$;


-- ===== Test 2: Settlement trigger settles points and grants reward =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Settlement trigger'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 2 FAILED: tasker balance should be 9 after settlement';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 2 FAILED: tasker locked should be 0 after settlement';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 2 FAILED: referee reward should be 1';
  ASSERT (SELECT COUNT(*) FROM public.point_ledger
    WHERE user_id = '11111111-1111-1111-1111-111111111111' AND reason = 'matching_settled') >= 1,
    'Test 2 FAILED: should have matching_settled point ledger entry';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger
    WHERE user_id = '22222222-2222-2222-2222-222222222222' AND reason = 'evidence_timeout') = 1,
    'Test 2 FAILED: should have evidence_timeout reward ledger entry';
  RAISE NOTICE 'Test 2 PASSED: points consumed from tasker, reward granted to referee';
END $$;


-- ===== Test 3: is_evidence_timeout_confirmed auto-set and request closed =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Auto-close referee side'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT is_evidence_timeout_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 3 FAILED: is_evidence_timeout_confirmed should be true';
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 3 FAILED: request should be closed';
  RAISE NOTICE 'Test 3 PASSED: referee side auto-closed';
END $$;


-- ===== Test 4: Task stays open (is_confirmed still false) =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Task stays open for tasker'
\echo '=========================================='

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = false,
    'Test 4 FAILED: is_confirmed should still be false';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'open',
    'Test 4 FAILED: task should still be open';
  RAISE NOTICE 'Test 4 PASSED: task stays open, tasker must confirm';
END $$;


-- ===== Test 5: Tasker confirms evidence timeout → task closes =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Tasker confirm closes task'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_evidence_timeout('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 5 FAILED: is_confirmed should be true';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 5 FAILED: task should be closed after tasker confirms';
  RAISE NOTICE 'Test 5 PASSED: tasker confirm closes task';
END $$;


-- ===== Test 6: Idempotency — second confirm does not fail =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Confirm idempotency'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_evidence_timeout('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 6 FAILED: balance should still be 9 (no double-consume)';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 6 FAILED: reward should still be 1 (no double-grant)';
  RAISE NOTICE 'Test 6 PASSED: idempotency prevents double-processing';
END $$;


-- ===== Test 7: Detection does not affect tasks with evidence =====
\echo ''
\echo '=========================================='
\echo ' Test 7: Tasks with evidence are not affected'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Has Evidence Task', 'Desc', 'Criteria', now() - interval '1 hour', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for evidence test');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'awaiting_evidence');

INSERT INTO public.task_evidences (id, task_id, description, status)
VALUES ('ffffffff-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'eeeeeeee-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'My evidence', 'ready');

SELECT public.detect_and_handle_evidence_timeouts();

DO $$
BEGIN
  ASSERT (SELECT status FROM public.judgements WHERE id = 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'awaiting_evidence',
    'Test 7 FAILED: status should still be awaiting_evidence (evidence exists)';
  RAISE NOTICE 'Test 7 PASSED: tasks with evidence are not affected';
END $$;


-- ===== Test 8: Normal confirm flow still works (regression) =====
\echo ''
\echo '=========================================='
\echo ' Test 8: Normal confirm flow regression'
\echo '=========================================='

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Normal Flow Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 1, 'matching_lock'::public.point_reason, 'Lock for normal flow');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee('bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa', true, 'Good job');

DO $$
BEGIN
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'bbbbbbbb-bbbb-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 8 FAILED: request should be closed';
  ASSERT (SELECT status FROM public.tasks WHERE id = 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 8 FAILED: task should be closed';
  RAISE NOTICE 'Test 8 PASSED: normal confirm flow still works';
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
git add supabase/tests/test_evidence_timeout_settlement.sql
git commit -m "test: add evidence timeout settlement tests"
```

---

### Task 8: Generate migration, apply, and run tests

**Step 1: Generate migration**

```bash
supabase db diff -f add_evidence_timeout_settlement
```

**Step 2: Review the generated migration**

Read the file and verify it includes all expected changes.

**Step 3: Apply migration**

```bash
supabase migration up
```

**Step 4: Run the new tests**

```bash
docker cp supabase/tests/test_evidence_timeout_settlement.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_evidence_timeout_settlement.sql
```

Expected: All 8 tests PASSED.

**Step 5: Run existing tests for regression**

```bash
docker cp supabase/tests/test_reward_system.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_reward_system.sql
```

```bash
docker cp supabase/tests/test_confirm_judgement.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_confirm_judgement.sql
```

Expected: All existing tests still pass.

**Step 6: Fix any failures, re-run until green, then commit migration**

```bash
git add supabase/migrations/*_add_evidence_timeout_settlement.sql
git commit -m "feat: add evidence timeout settlement migration"
```

---

### Task Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Settlement trigger | `schemas/judgement/triggers/on_evidence_timeout_settle.sql` |
| 2 | Tasker confirm function | `schemas/judgement/functions/confirm_evidence_timeout.sql` |
| 3 | Task closure refactor | Delete old, create `schemas/task/triggers/on_all_judgements_confirmed_close_task.sql` |
| 4 | Cleanup obsolete code | Delete `confirm_evidence_timeout_from_referee`, update trigger comments |
| 5 | Cron job schedule | `schemas/judgement/cron/cron_detect_evidence_timeout.sql` |
| 6 | Generate migration + apply | `supabase db diff -f` → `supabase migration up` |
| 7 | Tests | `tests/test_evidence_timeout_settlement.sql` |
| 8 | Run tests and verify | All tests pass, commit migration |
