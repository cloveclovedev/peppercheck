# Fix Point Lock on Task Open — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure points are locked in `point_wallets.locked` when a task is opened, so `consume_points()` succeeds at confirm time.

**Architecture:** Add `lock_points()` call inside `create_task_referee_requests_from_json()`. Simplify `validate_task_open_requirements()` to use `point_wallets.locked` directly. Remove the now-redundant `calculate_locked_points_by_active_tasks()` function.

**Tech Stack:** PostgreSQL (plpgsql), Supabase migrations

---

### Task 1: Add lock_points() call to create_task_referee_requests_from_json()

**Files:**
- Modify: `supabase/schemas/task/functions/utils/create_task_referee_requests_from_json.sql`

**Step 1: Edit the function to add lock_points() call after each INSERT**

Add a `v_tasker_id` variable declaration. Before the loop, look up the `tasker_id` from `tasks`. After each INSERT, call `lock_points()`:

```sql
CREATE OR REPLACE FUNCTION public.create_task_referee_requests_from_json(
    p_task_id uuid,
    p_requests jsonb[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req jsonb;
    v_strategy public.matching_strategy;
    v_pref_referee uuid;
    v_tasker_id uuid;
BEGIN
    IF p_requests IS NOT NULL THEN
        -- Look up task owner once
        SELECT tasker_id INTO v_tasker_id
        FROM public.tasks
        WHERE id = p_task_id;

        FOREACH v_req IN ARRAY p_requests
        LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;

            IF (v_req->>'preferred_referee_id') IS NOT NULL THEN
                v_pref_referee := (v_req->>'preferred_referee_id')::uuid;
            ELSE
                v_pref_referee := NULL;
            END IF;

            INSERT INTO public.task_referee_requests (
                task_id,
                matching_strategy,
                preferred_referee_id,
                status
            )
            VALUES (
                p_task_id,
                v_strategy,
                v_pref_referee,
                'pending'::public.referee_request_status
            );

            -- Lock points for this matching request
            PERFORM public.lock_points(
                v_tasker_id,
                public.get_point_for_matching_strategy(v_strategy),
                'matching_lock'::public.point_reason,
                'Points locked for matching request',
                p_task_id
            );
        END LOOP;
    END IF;
END;
$$;

ALTER FUNCTION public.create_task_referee_requests_from_json(uuid, jsonb[]) OWNER TO postgres;
```

**Step 2: Commit**

```bash
git add supabase/schemas/task/functions/utils/create_task_referee_requests_from_json.sql
git commit -m "fix: add lock_points() call when creating task referee requests"
```

---

### Task 2: Simplify validate_task_open_requirements()

**Files:**
- Modify: `supabase/schemas/task/functions/utils/validate_task_open_requirements.sql`

**Step 1: Replace calculate_locked_points_by_active_tasks() with direct locked read**

Remove `v_locked_points` variable. Add `v_wallet_locked`. Read both `balance` and `locked` from `point_wallets`. Check `(balance - locked) >= new_cost`:

```sql
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
    v_new_cost int := 0;
    v_wallet_balance int;
    v_wallet_locked int;
    v_req jsonb;
    v_strategy public.matching_strategy;
BEGIN
    -- 1. Due Date Validation
    SELECT (value::text)::int INTO v_min_hours
    FROM public.matching_config
    WHERE key = 'min_due_date_interval_hours';

    IF v_min_hours IS NULL THEN
        RAISE EXCEPTION 'Configuration missing for min_due_date_interval_hours in matching_config';
    END IF;

    IF p_due_date <= (now() + (v_min_hours || ' hours')::interval) THEN
        RAISE EXCEPTION 'Due date must be at least % hours from now', v_min_hours;
    END IF;

    -- 2. Point Validation
    IF p_referee_requests IS NOT NULL THEN
        FOREACH v_req IN ARRAY p_referee_requests
        LOOP
            v_strategy := (v_req->>'matching_strategy')::public.matching_strategy;
            v_new_cost := v_new_cost + public.get_point_for_matching_strategy(v_strategy);
        END LOOP;
    END IF;

    SELECT balance, locked INTO v_wallet_balance, v_wallet_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id;

    IF v_wallet_balance IS NULL THEN
        RAISE EXCEPTION 'Point wallet not found for user';
    END IF;

    IF (v_wallet_balance - v_wallet_locked) < v_new_cost THEN
         RAISE EXCEPTION 'Insufficient points. Balance: %, Locked: %, Required: %', v_wallet_balance, v_wallet_locked, v_new_cost;
    END IF;
END;
$$;

ALTER FUNCTION public.validate_task_open_requirements(uuid, timestamp with time zone, jsonb[]) OWNER TO postgres;
```

**Step 2: Commit**

```bash
git add supabase/schemas/task/functions/utils/validate_task_open_requirements.sql
git commit -m "refactor: simplify validate_task_open_requirements to use point_wallets.locked"
```

---

### Task 3: Delete calculate_locked_points_by_active_tasks()

**Files:**
- Delete: `supabase/schemas/point/functions/calculate_locked_points_by_active_tasks.sql`
- Modify: `supabase/config.toml` (remove reference from `schema_sql_paths`)

**Step 1: Delete the function file**

```bash
rm supabase/schemas/point/functions/calculate_locked_points_by_active_tasks.sql
```

**Step 2: Remove from config.toml**

Remove the line containing `"./schemas/point/functions/calculate_locked_points_by_active_tasks.sql",` from the `schema_sql_paths` array.

**Step 3: Commit**

```bash
git add supabase/schemas/point/functions/calculate_locked_points_by_active_tasks.sql supabase/config.toml
git commit -m "refactor: remove calculate_locked_points_by_active_tasks (replaced by point_wallets.locked)"
```

---

### Task 4: Generate migration file

**Step 1: Generate migration from schema diff**

```bash
supabase db diff -f fix_point_lock_on_task_open
```

This compares the schema SQL files against the current database state and generates a migration file automatically.

**Step 2: Review the generated migration**

Read the generated file at `supabase/migrations/*_fix_point_lock_on_task_open.sql` and verify it contains:
1. Updated `create_task_referee_requests_from_json` with `lock_points()` call
2. Updated `validate_task_open_requirements` without `calculate_locked_points_by_active_tasks`
3. `DROP FUNCTION` for `calculate_locked_points_by_active_tasks`

**Step 3: Commit**

```bash
git add supabase/migrations/*_fix_point_lock_on_task_open.sql
git commit -m "fix: lock points when task is opened (migration)"
```

---

### Task 5: Apply migration and run tests

**Step 1: Apply the migration**

```bash
supabase migration up
```

**Step 2: Add test for lock-on-create flow**

In `supabase/tests/test_reward_system.sql`, add a new Test 10 before the cleanup/ROLLBACK section:

```sql
-- ===== Test 10: create_task_referee_requests_from_json locks points =====
\echo ''
\echo '=========================================='
\echo ' Test 10: create_task_referee_requests_from_json locks points'
\echo '=========================================='

-- Reset state
UPDATE public.point_wallets SET balance = 5, locked = 0 WHERE user_id = '11111111-1111-1111-1111-111111111111';

-- Create a fresh task (inserted directly, not via RPC, to isolate the helper)
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Lock Test Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

-- Call the helper that should now lock points
SELECT public.create_task_referee_requests_from_json(
  'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  ARRAY['{"matching_strategy": "standard"}'::jsonb]
);

DO $$
BEGIN
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 10 FAILED: locked should be 1 after create_task_referee_requests_from_json';
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 5,
    'Test 10 FAILED: balance should remain 5 (lock does not deduct balance)';
  ASSERT (SELECT COUNT(*) FROM public.point_ledger
    WHERE user_id = '11111111-1111-1111-1111-111111111111'
    AND reason = 'matching_lock'
    AND related_id = 'dddddddd-aaaa-aaaa-aaaa-aaaaaaaaaaaa') >= 1,
    'Test 10 FAILED: should have matching_lock ledger entry for this task';
  RAISE NOTICE 'Test 10 PASSED: create_task_referee_requests_from_json locks points correctly';
END $$;
```

**Step 3: Run the tests**

```bash
docker cp supabase/tests/test_reward_system.sql supabase_db_peppercheck:/tmp/ && \
docker exec supabase_db_peppercheck psql -U postgres -f /tmp/test_reward_system.sql
```

Expected: All 10 tests PASSED, transaction rolled back.

**Step 4: Commit test**

```bash
git add supabase/tests/test_reward_system.sql
git commit -m "test: add test for point locking on task referee request creation"
```
