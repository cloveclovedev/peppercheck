# Confirm Reward Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add point lock/settle mechanics and referee reward wallets so that points are reserved at task creation, consumed at Confirm, and referee rewards are pooled.

**Architecture:** Replace immediate point consumption with a lock/settle pattern. New `reward_wallets` and `reward_ledger` tables track referee earnings. The existing `confirm_judgement_and_rate_referee` RPC is extended to atomically settle points and grant rewards in one transaction.

**Tech Stack:** PostgreSQL (Supabase), PL/pgSQL functions, RLS policies, SQL integration tests

---

### Task 1: Add new point_reason enum values, locked column, and delete enums.sql

**Files:**
- Modify: `supabase/schemas/point/tables/point_ledger.sql` (move enum here from enums.sql)
- Delete: `supabase/schemas/point/tables/enums.sql`
- Modify: `supabase/schemas/point/tables/point_wallets.sql`

**Step 1: Move point_reason enum into point_ledger.sql**

The `point_reason` enum is only used by `point_ledger`, so declare it in the same file.
Add the enum declaration at the top of `supabase/schemas/point/tables/point_ledger.sql` (before the CREATE TABLE), with the new values added:

```sql
CREATE TYPE public.point_reason AS ENUM (
    'plan_renewal',      -- Monthly subscription points grant
    'plan_upgrade',      -- Prorated points adjustment on upgrade
    'matching_request',  -- (Legacy) Consumed when requesting a referee matching
    'matching_lock',     -- Points locked when requesting a referee matching
    'matching_unlock',   -- Points unlocked (returned) on timeout
    'matching_settled',  -- Points consumed at Confirm
    'matching_refund',   -- Refunded if matching fails or task is cancelled
    'manual_adjustment', -- Admin operation/Support
    'referral_bonus'     -- Points earned from referring users
);

CREATE TABLE IF NOT EXISTS public.point_ledger (
    ...existing columns...
);
```

**Step 2: Delete enums.sql**

Delete `supabase/schemas/point/tables/enums.sql` since the enum is now in `point_ledger.sql`.

**Step 3: Update the point_wallets schema file**

Add `locked` column to `supabase/schemas/point/tables/point_wallets.sql`:

```sql
CREATE TABLE IF NOT EXISTS public.point_wallets (
    user_id uuid NOT NULL,
    balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
    locked integer NOT NULL DEFAULT 0 CHECK (locked >= 0),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT point_wallets_pkey PRIMARY KEY (user_id),
    CONSTRAINT point_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT point_wallets_balance_gte_locked CHECK (balance >= locked)
);

ALTER TABLE public.point_wallets OWNER TO postgres;
```

**Step 4: Commit**

```bash
git add supabase/schemas/point/tables/point_ledger.sql supabase/schemas/point/tables/point_wallets.sql
git rm supabase/schemas/point/tables/enums.sql
git commit -m "feat(schema): add point lock enum values and locked column, move enum to ledger"
```

---

### Task 2: Create reward_wallets and reward_ledger tables

**Files:**
- Create: `supabase/schemas/reward/tables/reward_wallets.sql`
- Create: `supabase/schemas/reward/tables/reward_ledger.sql` (includes reward_reason enum)
- Create: `supabase/schemas/reward/policies/reward_wallets_policies.sql`
- Create: `supabase/schemas/reward/policies/reward_ledger_policies.sql`
- Create: `supabase/schemas/reward/triggers/on_reward_wallets_update_set_updated_at.sql`

**Step 1: Create reward_wallets table**

Create `supabase/schemas/reward/tables/reward_wallets.sql`:

```sql
CREATE TABLE IF NOT EXISTS public.reward_wallets (
    user_id uuid NOT NULL,
    balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_wallets_pkey PRIMARY KEY (user_id),
    CONSTRAINT reward_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.reward_wallets OWNER TO postgres;
```

**Step 2: Create reward_ledger table with inline reward_reason enum**

Create `supabase/schemas/reward/tables/reward_ledger.sql` (enum declared in the same file, same pattern as point_ledger.sql):

```sql
CREATE TYPE public.reward_reason AS ENUM (
    'review_completed',   -- Reward for completing a review (Confirm)
    'evidence_timeout',   -- Reward when Tasker times out on evidence
    'payout',             -- Monthly payout to bank account
    'manual_adjustment'   -- Admin operation
);

CREATE TABLE IF NOT EXISTS public.reward_ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount integer NOT NULL,
    reason public.reward_reason NOT NULL,
    description text,
    related_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_ledger_pkey PRIMARY KEY (id),
    CONSTRAINT reward_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.reward_ledger OWNER TO postgres;

-- Indexes
CREATE INDEX idx_reward_ledger_user_id ON public.reward_ledger USING btree (user_id);
CREATE INDEX idx_reward_ledger_created_at ON public.reward_ledger USING btree (created_at);
```

**Step 3: Create RLS policies for reward_wallets**

Create `supabase/schemas/reward/policies/reward_wallets_policies.sql`:

```sql
ALTER TABLE public.reward_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reward_wallets: select if self" ON public.reward_wallets
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
```

**Step 4: Create RLS policies for reward_ledger**

Create `supabase/schemas/reward/policies/reward_ledger_policies.sql`:

```sql
ALTER TABLE public.reward_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reward_ledger: select if self" ON public.reward_ledger
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
```

**Step 5: Create updated_at trigger for reward_wallets**

Create `supabase/schemas/reward/triggers/on_reward_wallets_update_set_updated_at.sql`:

```sql
CREATE TRIGGER on_reward_wallets_update_set_updated_at
    BEFORE UPDATE ON public.reward_wallets
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
```

**Step 6: Commit**

```bash
git add supabase/schemas/reward/
git commit -m "feat(schema): add reward_wallets and reward_ledger tables with RLS"
```

---

### Task 3: Create lock_points and unlock_points functions

**Files:**
- Create: `supabase/schemas/point/functions/lock_points.sql`
- Create: `supabase/schemas/point/functions/unlock_points.sql`

**Step 1: Create lock_points function**

Create `supabase/schemas/point/functions/lock_points.sql`:

```sql
CREATE OR REPLACE FUNCTION public.lock_points(
    p_user_id uuid,
    p_amount integer,
    p_reason public.point_reason,
    p_description text DEFAULT NULL,
    p_related_id uuid DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_balance integer;
    v_locked integer;
BEGIN
    -- Lock row and get current state
    SELECT balance, locked INTO v_balance, v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    -- Check available (unlocked) balance
    IF (v_balance - v_locked) < p_amount THEN
        RAISE EXCEPTION 'Insufficient available points: required %, available %', p_amount, (v_balance - v_locked);
    END IF;

    -- Increase locked amount (balance unchanged)
    UPDATE public.point_wallets
    SET locked = locked + p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Insert ledger entry
    INSERT INTO public.point_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        -p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$$;

ALTER FUNCTION public.lock_points(uuid, integer, public.point_reason, text, uuid) OWNER TO postgres;
```

**Step 2: Create unlock_points function**

Create `supabase/schemas/point/functions/unlock_points.sql`:

```sql
CREATE OR REPLACE FUNCTION public.unlock_points(
    p_user_id uuid,
    p_amount integer,
    p_reason public.point_reason,
    p_description text DEFAULT NULL,
    p_related_id uuid DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_locked integer;
BEGIN
    -- Lock row and get current locked amount
    SELECT locked INTO v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_locked IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked points: requested %, locked %', p_amount, v_locked;
    END IF;

    -- Decrease locked amount (balance unchanged — points returned to available)
    UPDATE public.point_wallets
    SET locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Insert ledger entry (positive = points returned)
    INSERT INTO public.point_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$$;

ALTER FUNCTION public.unlock_points(uuid, integer, public.point_reason, text, uuid) OWNER TO postgres;
```

**Step 3: Commit**

```bash
git add supabase/schemas/point/functions/lock_points.sql supabase/schemas/point/functions/unlock_points.sql
git commit -m "feat(point): add lock_points and unlock_points functions"
```

---

### Task 4: Modify consume_points to settle locked points

**Files:**
- Modify: `supabase/schemas/point/functions/consume_points.sql`

**Step 1: Update consume_points to deduct from both balance and locked**

Replace the contents of `supabase/schemas/point/functions/consume_points.sql`:

```sql
CREATE OR REPLACE FUNCTION public.consume_points(
    p_user_id uuid,
    p_amount integer,
    p_reason public.point_reason,
    p_description text DEFAULT NULL,
    p_related_id uuid DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_balance integer;
    v_locked integer;
BEGIN
    -- Lock row and get current state
    SELECT balance, locked INTO v_balance, v_locked
    FROM public.point_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient points: required %, available %', p_amount, v_balance;
    END IF;

    IF v_locked < p_amount THEN
        RAISE EXCEPTION 'Insufficient locked points: required %, locked %', p_amount, v_locked;
    END IF;

    -- Settle: deduct from both balance and locked
    UPDATE public.point_wallets
    SET balance = balance - p_amount,
        locked = locked - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Insert ledger entry
    INSERT INTO public.point_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        -p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$$;

ALTER FUNCTION public.consume_points(uuid, integer, public.point_reason, text, uuid) OWNER TO postgres;
```

**Step 2: Commit**

```bash
git add supabase/schemas/point/functions/consume_points.sql
git commit -m "feat(point): update consume_points to settle locked points"
```

---

### Task 5: Create grant_reward function

**Files:**
- Create: `supabase/schemas/reward/functions/grant_reward.sql`

**Step 1: Create grant_reward function**

Create `supabase/schemas/reward/functions/grant_reward.sql`:

```sql
CREATE OR REPLACE FUNCTION public.grant_reward(
    p_user_id uuid,
    p_amount integer,
    p_reason public.reward_reason,
    p_description text DEFAULT NULL,
    p_related_id uuid DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    -- Upsert reward wallet (create if not exists)
    INSERT INTO public.reward_wallets (user_id, balance)
    VALUES (p_user_id, p_amount)
    ON CONFLICT (user_id) DO UPDATE
    SET balance = public.reward_wallets.balance + p_amount,
        updated_at = now();

    -- Insert ledger entry
    INSERT INTO public.reward_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        p_amount,
        p_reason,
        p_description,
        p_related_id
    );
END;
$$;

ALTER FUNCTION public.grant_reward(uuid, integer, public.reward_reason, text, uuid) OWNER TO postgres;
```

**Step 2: Commit**

```bash
git add supabase/schemas/reward/functions/grant_reward.sql
git commit -m "feat(reward): add grant_reward function"
```

---

### Task 6: Modify create_matching_request to use lock_points

**Files:**
- Modify: `supabase/schemas/matching/functions/create_matching_request.sql`

**Step 1: Replace consume_points with lock_points**

In `supabase/schemas/matching/functions/create_matching_request.sql`, replace the `consume_points` call:

Change:
```sql
    -- Consume Points (Atomic transaction)
    -- Using 'matching_request' reason code
    PERFORM public.consume_points(
        v_user_id,
        v_cost,
        'matching_request'::public.point_reason,
        'Matching Request (' || p_matching_strategy || ')',
        p_task_id
    );
```

To:
```sql
    -- Lock Points (reserved until Confirm settles them)
    PERFORM public.lock_points(
        v_user_id,
        v_cost,
        'matching_lock'::public.point_reason,
        'Matching Request (' || p_matching_strategy || ')',
        p_task_id
    );
```

**Step 2: Commit**

```bash
git add supabase/schemas/matching/functions/create_matching_request.sql
git commit -m "feat(matching): use lock_points instead of consume_points in create_matching_request"
```

---

### Task 7: Extend confirm_judgement_and_rate_referee with point settlement and reward

**Files:**
- Modify: `supabase/schemas/judgement/functions/confirm_judgement_and_rate_referee.sql`

**Step 1: Add point settlement and reward granting**

Replace the contents of `supabase/schemas/judgement/functions/confirm_judgement_and_rate_referee.sql`:

```sql
CREATE OR REPLACE FUNCTION public.confirm_judgement_and_rate_referee(
    p_judgement_id uuid,
    p_is_positive boolean,
    p_comment text DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
    v_rows_affected integer;
    v_cost integer;
BEGIN
    -- Get judgement details with task and referee info
    SELECT
        j.id,
        j.status,
        j.is_confirmed,
        trr.task_id,
        trr.matched_referee_id AS referee_id,
        trr.matching_strategy,
        t.tasker_id
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
        RAISE EXCEPTION 'Only the tasker can confirm a judgement';
    END IF;

    -- Validate judgement status
    IF v_judgement.status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Judgement must be in approved or rejected status to confirm';
    END IF;

    -- Idempotency: if already confirmed, do nothing
    IF v_judgement.is_confirmed = TRUE THEN
        RETURN;
    END IF;

    -- Determine point cost from matching strategy
    v_cost := public.get_point_for_matching_strategy(v_judgement.matching_strategy);

    -- Settle points: consume locked points from tasker
    PERFORM public.consume_points(
        v_judgement.tasker_id,
        v_cost,
        'matching_settled'::public.point_reason,
        'Review confirmed (judgement ' || p_judgement_id || ')',
        p_judgement_id
    );

    -- Grant reward to referee
    PERFORM public.grant_reward(
        v_judgement.referee_id,
        v_cost,
        'review_completed'::public.reward_reason,
        'Review completed (judgement ' || p_judgement_id || ')',
        p_judgement_id
    );

    -- Insert rating (tasker rates referee)
    INSERT INTO public.rating_histories (
        judgement_id,
        ratee_id,
        rater_id,
        rating_type,
        is_positive,
        comment
    ) VALUES (
        p_judgement_id,
        v_judgement.referee_id,
        (SELECT auth.uid()),
        'referee',
        p_is_positive,
        p_comment
    );

    -- Confirm judgement
    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Failed to update judgement confirmation status';
    END IF;
END;
$$;

ALTER FUNCTION public.confirm_judgement_and_rate_referee(uuid, boolean, text) OWNER TO postgres;

COMMENT ON FUNCTION public.confirm_judgement_and_rate_referee(uuid, boolean, text) IS 'Atomically confirms a judgement, settles points (consumes from tasker, rewards referee), and records a binary rating. Called by the tasker after reviewing the referee''s judgement. Only valid for approved/rejected judgements.';
```

**Step 2: Commit**

```bash
git add supabase/schemas/judgement/functions/confirm_judgement_and_rate_referee.sql
git commit -m "feat(judgement): add point settlement and reward granting to confirm RPC"
```

---

### Task 8: Generate and apply migration file

**Step 1: Generate migration with supabase db diff**

After all schema files have been updated (Tasks 1-7), generate the migration:

```bash
supabase db diff -f add_reward_system_and_point_lock
```

This auto-generates a timestamped migration file in `supabase/migrations/`.

**Step 2: Review the generated migration**

Open the generated file and verify it includes:
- `ALTER TYPE public.point_reason ADD VALUE` for new enum values
- `ALTER TABLE public.point_wallets ADD COLUMN locked`
- `CREATE TYPE public.reward_reason`
- `CREATE TABLE public.reward_wallets` and `public.reward_ledger`
- All function CREATE OR REPLACE statements
- RLS policies, indexes, and triggers

**Note:** `supabase db diff` may not capture enum value additions (`ALTER TYPE ... ADD VALUE`). If missing, manually prepend these lines to the generated migration:

```sql
ALTER TYPE public.point_reason ADD VALUE IF NOT EXISTS 'matching_lock';
ALTER TYPE public.point_reason ADD VALUE IF NOT EXISTS 'matching_unlock';
ALTER TYPE public.point_reason ADD VALUE IF NOT EXISTS 'matching_settled';
```

**Step 3: Apply migration**

```bash
supabase migration up
```

**Step 4: Commit**

```bash
git add supabase/migrations/*_add_reward_system_and_point_lock.sql
git commit -m "feat(migration): add reward system and point lock migration"
```

---

### Task 9: Write integration tests

**Files:**
- Create: `supabase/tests/test_reward_system.sql`

**Step 1: Write the test file**

Create `supabase/tests/test_reward_system.sql`:

```sql
-- =============================================================================
-- Test: Reward System & Point Lock/Settle
--
-- Usage:
--   docker cp supabase/tests/test_reward_system.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_reward_system.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: Reward System & Point Lock/Settle'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Creating test users...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Creating point wallet with 10 points...'

INSERT INTO public.point_wallets (user_id, balance, locked)
VALUES ('11111111-1111-1111-1111-111111111111', 10, 0);

\echo '[Setup] Creating task...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Task', 'Test description', 'Test criteria', now() + interval '7 days', 'open');


-- ===== Test 1: lock_points locks but does not reduce balance =====
\echo ''
\echo '=========================================='
\echo ' Test 1: lock_points'
\echo '=========================================='

SELECT public.lock_points(
  '11111111-1111-1111-1111-111111111111',
  1,
  'matching_lock'::public.point_reason,
  'Test lock',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 10,
    'Test 1 FAILED: balance should remain 10';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 1 FAILED: locked should be 1';
  ASSERT (SELECT COUNT(*) FROM public.point_ledger WHERE user_id = '11111111-1111-1111-1111-111111111111' AND reason = 'matching_lock') = 1,
    'Test 1 FAILED: should have ledger entry';
  RAISE NOTICE 'Test 1 PASSED: lock_points locks without reducing balance';
END $$;


-- ===== Test 2: lock_points fails when insufficient available points =====
\echo ''
\echo '=========================================='
\echo ' Test 2: lock_points insufficient available'
\echo '=========================================='

-- Lock 8 more (total locked: 9, available: 1)
SELECT public.lock_points('11111111-1111-1111-1111-111111111111', 8, 'matching_lock'::public.point_reason);

DO $$
BEGIN
  -- Try to lock 2 more (only 1 available)
  PERFORM public.lock_points('11111111-1111-1111-1111-111111111111', 2, 'matching_lock'::public.point_reason);
  RAISE NOTICE 'Test 2 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Insufficient available points%' THEN
      RAISE NOTICE 'Test 2 PASSED: insufficient available blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 2 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 3: unlock_points returns locked points to available =====
\echo ''
\echo '=========================================='
\echo ' Test 3: unlock_points'
\echo '=========================================='

SELECT public.unlock_points(
  '11111111-1111-1111-1111-111111111111',
  8,
  'matching_unlock'::public.point_reason,
  'Test unlock'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 10,
    'Test 3 FAILED: balance should remain 10';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 3 FAILED: locked should be 1';
  RAISE NOTICE 'Test 3 PASSED: unlock_points returns locked to available';
END $$;


-- ===== Test 4: consume_points settles (deducts from balance and locked) =====
\echo ''
\echo '=========================================='
\echo ' Test 4: consume_points settles'
\echo '=========================================='

SELECT public.consume_points(
  '11111111-1111-1111-1111-111111111111',
  1,
  'matching_settled'::public.point_reason,
  'Test settle'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 9,
    'Test 4 FAILED: balance should be 9';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 4 FAILED: locked should be 0';
  RAISE NOTICE 'Test 4 PASSED: consume_points settles locked points';
END $$;


-- ===== Test 5: consume_points fails when insufficient locked =====
\echo ''
\echo '=========================================='
\echo ' Test 5: consume_points insufficient locked'
\echo '=========================================='

DO $$
BEGIN
  -- No locked points, so consume should fail
  PERFORM public.consume_points('11111111-1111-1111-1111-111111111111', 1, 'matching_settled'::public.point_reason);
  RAISE NOTICE 'Test 5 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Insufficient locked points%' THEN
      RAISE NOTICE 'Test 5 PASSED: insufficient locked blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 5 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 6: grant_reward creates wallet and adds reward =====
\echo ''
\echo '=========================================='
\echo ' Test 6: grant_reward'
\echo '=========================================='

SELECT public.grant_reward(
  '22222222-2222-2222-2222-222222222222',
  1,
  'review_completed'::public.reward_reason,
  'Test reward',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 6 FAILED: reward balance should be 1';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 6 FAILED: should have 1 ledger entry';
  RAISE NOTICE 'Test 6 PASSED: grant_reward creates wallet and records ledger';
END $$;


-- ===== Test 7: grant_reward accumulates on existing wallet =====
\echo ''
\echo '=========================================='
\echo ' Test 7: grant_reward accumulates'
\echo '=========================================='

SELECT public.grant_reward(
  '22222222-2222-2222-2222-222222222222',
  2,
  'review_completed'::public.reward_reason,
  'Second reward'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 3,
    'Test 7 FAILED: reward balance should be 3';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222') = 2,
    'Test 7 FAILED: should have 2 ledger entries';
  RAISE NOTICE 'Test 7 PASSED: grant_reward accumulates rewards';
END $$;


-- ===== Test 8: Full confirm flow — lock, confirm, settle, reward =====
\echo ''
\echo '=========================================='
\echo ' Test 8: Full confirm flow'
\echo '=========================================='

-- Reset: set wallet to clean state
UPDATE public.point_wallets SET balance = 5, locked = 0 WHERE user_id = '11111111-1111-1111-1111-111111111111';
DELETE FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222';
DELETE FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222';

-- Create a fresh task for this test
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Confirm Flow Task', 'Desc', 'Criteria', now() + interval '7 days', 'open');

-- Simulate create_matching_request: lock 1 point
SELECT public.lock_points(
  '11111111-1111-1111-1111-111111111111',
  1,
  'matching_lock'::public.point_reason,
  'Matching Request (standard)',
  'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

-- Create request and judgement
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'approved');

-- Verify state before confirm
DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 5,
    'Test 8 pre-check FAILED: balance should be 5 (locked, not consumed)';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 1,
    'Test 8 pre-check FAILED: locked should be 1';
  RAISE NOTICE 'Test 8 pre-check: balance=5, locked=1 (correct)';
END $$;

-- Confirm judgement (as tasker)
SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  true,
  'Great review!'
);

-- Verify state after confirm
DO $$
BEGIN
  -- Tasker: balance reduced by 1, locked reduced by 1
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 4,
    'Test 8 FAILED: tasker balance should be 4 after settle';
  ASSERT (SELECT locked FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 0,
    'Test 8 FAILED: tasker locked should be 0 after settle';

  -- Referee: reward wallet created with 1 point
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 8 FAILED: referee reward should be 1';

  -- Ledger entries
  ASSERT (SELECT COUNT(*) FROM public.point_ledger WHERE user_id = '11111111-1111-1111-1111-111111111111' AND reason = 'matching_settled') >= 1,
    'Test 8 FAILED: should have matching_settled ledger entry';
  ASSERT (SELECT COUNT(*) FROM public.reward_ledger WHERE user_id = '22222222-2222-2222-2222-222222222222' AND reason = 'review_completed') = 1,
    'Test 8 FAILED: should have review_completed reward ledger entry';

  -- Judgement confirmed
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 8 FAILED: judgement should be confirmed';

  -- Rating recorded
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = true,
    'Test 8 FAILED: rating should be positive';

  RAISE NOTICE 'Test 8 PASSED: full confirm flow — lock, confirm, settle, reward all correct';
END $$;


-- ===== Test 9: Idempotency — second confirm does not double-spend =====
\echo ''
\echo '=========================================='
\echo ' Test 9: Confirm idempotency (no double-spend)'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  false,
  'Changed mind'
);

DO $$
BEGIN
  ASSERT (SELECT balance FROM public.point_wallets WHERE user_id = '11111111-1111-1111-1111-111111111111') = 4,
    'Test 9 FAILED: balance should still be 4 (no double-spend)';
  ASSERT (SELECT balance FROM public.reward_wallets WHERE user_id = '22222222-2222-2222-2222-222222222222') = 1,
    'Test 9 FAILED: reward should still be 1 (no double-grant)';
  RAISE NOTICE 'Test 9 PASSED: idempotency prevents double-spend';
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

**Step 2: Run tests**

```bash
docker cp supabase/tests/test_reward_system.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_reward_system.sql
```

Expected: All 9 tests PASSED.

**Step 3: Commit**

```bash
git add supabase/tests/test_reward_system.sql
git commit -m "test: add reward system and point lock integration tests"
```

---

### Task 10: Run existing confirm_judgement tests to verify no regressions

**Step 1: Run existing confirm_judgement tests**

The existing tests in `supabase/tests/test_confirm_judgement.sql` need updating because they don't set up point wallets with locked points. The confirm RPC now calls `consume_points` which requires locked points.

Update `supabase/tests/test_confirm_judgement.sql` to add point wallet setup after user creation:

After the `INSERT INTO auth.users` block, add:

```sql
\echo '[Setup] Creating point wallets...'

INSERT INTO public.point_wallets (user_id, balance, locked)
VALUES ('11111111-1111-1111-1111-111111111111', 100, 10);
```

This gives the tasker 100 points with 10 locked (enough for all test cases that call confirm, which each settle 1 locked point from a standard request).

**Step 2: Run updated tests**

```bash
docker cp supabase/tests/test_confirm_judgement.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_confirm_judgement.sql
```

Expected: All 8 tests PASSED.

**Step 3: Run new reward system tests**

```bash
docker cp supabase/tests/test_reward_system.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_reward_system.sql
```

Expected: All 9 tests PASSED.

**Step 4: Commit the test fix**

```bash
git add supabase/tests/test_confirm_judgement.sql
git commit -m "test: add point wallet setup to confirm_judgement tests for new lock/settle flow"
```
