# Confirm Judgement & Binary Rating Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement manual Confirm & Rate functionality for approved/rejected judgements, migrating from 5-star to binary rating system.

**Architecture:** Modify existing Supabase schema files to use binary ratings (`is_positive boolean`), update the `confirm_judgement_and_rate_referee` RPC, restructure close-flow triggers into a 2-step process (judgement confirmed -> request closed -> task closed), and add confirmation notifications to referees.

**Tech Stack:** PostgreSQL (Supabase), PL/pgSQL

**Design Doc:** `docs/plans/2026-02-14-confirm-judgement-design.md`

---

### Task 1: Schema - rating_histories table

**Files:**
- Modify: `supabase/schemas/rating/tables/rating_histories.sql`

**Step 1: Rewrite rating_histories.sql**

Replace the entire file with:

```sql
-- Enum: rating_type (only used by rating_histories)
CREATE TYPE public.rating_type AS ENUM ('tasker', 'referee');

-- Table: rating_histories
CREATE TABLE IF NOT EXISTS public.rating_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    judgement_id uuid NOT NULL,
    ratee_id uuid,
    rater_id uuid,
    rating_type public.rating_type NOT NULL,
    is_positive boolean NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT rating_history_pkey PRIMARY KEY (id),
    CONSTRAINT unique_rating_per_judgement UNIQUE (judgement_id, rating_type)
);

ALTER TABLE public.rating_histories OWNER TO postgres;

-- Indexes
CREATE INDEX idx_rating_histories_ratee_id ON public.rating_histories USING btree (ratee_id);
CREATE INDEX idx_rating_histories_ratee_type ON public.rating_histories USING btree (ratee_id, rating_type);

COMMENT ON COLUMN public.rating_histories.ratee_id IS 'ID of the user who received the rating';
COMMENT ON COLUMN public.rating_histories.rater_id IS 'ID of the user who gave the rating; set by RPC';
COMMENT ON COLUMN public.rating_histories.judgement_id IS 'ID of the specific judgement this rating is for';
COMMENT ON COLUMN public.rating_histories.is_positive IS 'Binary rating: true = positive, false = negative';
COMMENT ON CONSTRAINT unique_rating_per_judgement ON public.rating_histories IS 'One rating per rating_type per judgement. Enables ON CONFLICT in auto_score_timeout_referee.';

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_judgement_id FOREIGN KEY (judgement_id) REFERENCES public.judgements(id);

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_rater_id FOREIGN KEY (rater_id) REFERENCES public.profiles(id);

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_ratee_id FOREIGN KEY (ratee_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
```

Key changes from current:
- Added `rating_type` enum definition at top
- `rating numeric` -> `is_positive boolean NOT NULL`
- Removed `task_id` column and its FK/index
- `rating_type text` with CHECK -> `rating_type public.rating_type` (enum)
- Removed `rating_histories_rating_check` constraint
- Changed unique constraint from `(rater_id, ratee_id, judgement_id)` to `(judgement_id, rating_type)`
- `judgement_id` now `NOT NULL`
- Renamed indexes: `idx_rating_histories_user_id` -> `idx_rating_histories_ratee_id`, `idx_rating_histories_user_type` -> `idx_rating_histories_ratee_type`
- Removed `idx_rating_histories_task_id`

**Step 2: Commit**

```bash
git add supabase/schemas/rating/tables/rating_histories.sql
git commit -m "refactor(supabase): migrate rating_histories to binary rating system

Replace numeric 0-5 rating with is_positive boolean. Remove task_id
column (derivable via judgement_id). Convert rating_type to enum.
Update unique constraint to (judgement_id, rating_type)."
```

---

### Task 2: Schema - user_ratings table

**Files:**
- Modify: `supabase/schemas/rating/tables/user_ratings.sql`

**Step 1: Rewrite user_ratings.sql**

Replace the entire file with:

```sql
-- Table: user_ratings
CREATE TABLE IF NOT EXISTS public.user_ratings (
    user_id uuid NOT NULL,
    tasker_positive_count integer DEFAULT 0,
    tasker_total_count integer DEFAULT 0,
    tasker_positive_pct numeric DEFAULT 0,
    referee_positive_count integer DEFAULT 0,
    referee_total_count integer DEFAULT 0,
    referee_positive_pct numeric DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.user_ratings OWNER TO postgres;

ALTER TABLE ONLY public.user_ratings
    ADD CONSTRAINT user_ratings_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.user_ratings
    ADD CONSTRAINT user_ratings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
```

Key changes: `tasker_rating`/`tasker_rating_count`/`referee_rating`/`referee_rating_count` replaced with `*_positive_count`, `*_total_count`, `*_positive_pct` columns.

**Step 2: Commit**

```bash
git add supabase/schemas/rating/tables/user_ratings.sql
git commit -m "refactor(supabase): update user_ratings for binary rating aggregation

Replace AVG-based tasker_rating/referee_rating columns with
positive_count/total_count/positive_pct for binary rating system."
```

---

### Task 3: Function - update_user_ratings

**Files:**
- Modify: `supabase/schemas/rating/functions/update_user_ratings.sql`

**Step 1: Rewrite update_user_ratings.sql**

Replace the entire file with:

```sql
CREATE OR REPLACE FUNCTION public.update_user_ratings() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    affected_user_id uuid;
    v_positive integer;
    v_total integer;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.ratee_id;
    ELSE
        affected_user_id := NEW.ratee_id;
    END IF;

    -- Recalculate tasker ratings
    SELECT
        COUNT(*) FILTER (WHERE is_positive = true),
        COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'tasker';

    UPDATE public.user_ratings
    SET
        tasker_positive_count = v_positive,
        tasker_total_count = v_total,
        tasker_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    -- Recalculate referee ratings
    SELECT
        COUNT(*) FILTER (WHERE is_positive = true),
        COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'referee';

    UPDATE public.user_ratings
    SET
        referee_positive_count = v_positive,
        referee_total_count = v_total,
        referee_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

ALTER FUNCTION public.update_user_ratings() OWNER TO postgres;
```

Key changes: `AVG(rating)` replaced with positive percentage calculation using `COUNT(*) FILTER (WHERE is_positive = true)`.

**Step 2: Commit**

```bash
git add supabase/schemas/rating/functions/update_user_ratings.sql
git commit -m "refactor(supabase): update_user_ratings for binary rating aggregation

Calculate positive_count, total_count, and positive_pct instead of
AVG(rating) to match new binary rating system."
```

---

### Task 4: Delete set_rater_id function and trigger

**Files:**
- Delete: `supabase/schemas/rating/functions/set_rater_id.sql`
- Delete: `supabase/schemas/rating/triggers/on_rating_histories_insert_set_rater_id.sql`

**Step 1: Delete files**

```bash
rm supabase/schemas/rating/functions/set_rater_id.sql
rm supabase/schemas/rating/triggers/on_rating_histories_insert_set_rater_id.sql
```

**Step 2: Commit**

```bash
git add -u supabase/schemas/rating/functions/set_rater_id.sql supabase/schemas/rating/triggers/on_rating_histories_insert_set_rater_id.sql
git commit -m "refactor(supabase): remove set_rater_id trigger

rater_id is now set directly in RPCs instead of via trigger."
```

---

### Task 5: Function - confirm_judgement_and_rate_referee RPC

**Files:**
- Modify: `supabase/schemas/judgement/functions/confirm_judgement_and_rate_referee.sql`

**Step 1: Rewrite confirm_judgement_and_rate_referee.sql**

Replace the entire file with:

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
BEGIN
    -- Get judgement details with task and referee info
    SELECT
        j.id,
        j.status,
        j.is_confirmed,
        trr.task_id,
        trr.matched_referee_id AS referee_id,
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

COMMENT ON FUNCTION public.confirm_judgement_and_rate_referee(uuid, boolean, text) IS 'Atomically confirms a judgement and records a binary rating for the referee. Called by the tasker after reviewing the referee''s judgement. Only valid for approved/rejected judgements.';
```

Key changes:
- Parameters: `(task_id, judgement_id, ratee_id, rating, comment)` -> `(judgement_id, is_positive, comment)`
- Added `SECURITY DEFINER`
- Derives `task_id`, `ratee_id`, `tasker_id` from `judgement_id` via JOINs
- Validates caller is tasker
- Validates status is `approved` or `rejected`
- Sets `rater_id` directly via `auth.uid()` (no trigger)
- Uses `is_positive boolean` instead of `rating integer`

**Step 2: Commit**

```bash
git add supabase/schemas/judgement/functions/confirm_judgement_and_rate_referee.sql
git commit -m "refactor(supabase): update confirm RPC for binary rating

Simplify parameters to (judgement_id, is_positive, comment). Derive
task/referee info from judgement. Add SECURITY DEFINER, tasker
validation, and status validation (approved/rejected only)."
```

---

### Task 6: Function - handle_judgement_confirmed (rename + notification)

**Files:**
- Rename: `supabase/schemas/judgement/functions/handle_judgement_confirmation.sql` -> `handle_judgement_confirmed.sql`

**Step 1: Delete old file and create new**

```bash
rm supabase/schemas/judgement/functions/handle_judgement_confirmation.sql
```

Create `supabase/schemas/judgement/functions/handle_judgement_confirmed.sql`:

```sql
CREATE OR REPLACE FUNCTION public.handle_judgement_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
BEGIN
    -- Only execute when is_confirmed changes from FALSE to TRUE
    IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN

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
                    'notification_judgement_confirmed',
                    ARRAY[v_task_title],
                    jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
                );
            END IF;
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_judgement_confirmed() OWNER TO postgres;
```

**Note:** The trigger for this function (`on_judgement_confirmed`) existed only in the init migration but was missing from the schemas/triggers directory. We will create it in Task 8.

**Step 2: Commit**

```bash
git add -u supabase/schemas/judgement/functions/handle_judgement_confirmation.sql
git add supabase/schemas/judgement/functions/handle_judgement_confirmed.sql
git commit -m "feat(supabase): rename handle_judgement_confirmed and add notification

Rename from handle_judgement_confirmation. Add notification to referee
when tasker confirms an approved/rejected judgement."
```

---

### Task 7: Function - handle_evidence_timeout_confirmed (rename)

**Files:**
- Rename: `supabase/schemas/judgement/functions/handle_evidence_timeout_confirmation.sql` -> `handle_evidence_timeout_confirmed.sql`

**Step 1: Rename and update function name**

```bash
rm supabase/schemas/judgement/functions/handle_evidence_timeout_confirmation.sql
```

Create `supabase/schemas/judgement/functions/handle_evidence_timeout_confirmed.sql`:

```sql
CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    -- Only proceed if is_evidence_timeout_confirmed was changed from false to true
    -- and the judgement status is evidence_timeout
    IF NEW.is_evidence_timeout_confirmed = true
       AND OLD.is_evidence_timeout_confirmed = false
       AND NEW.status = 'evidence_timeout' THEN

        -- Previously triggered billing logic here.
        -- Billing system has been removed.
        -- Request/task closure is handled by on_judgement_confirmed_close_request trigger.
        NULL;

    END IF;

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in handle_evidence_timeout_confirmed: %', SQLERRM;
        RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_evidence_timeout_confirmed() OWNER TO postgres;

COMMENT ON FUNCTION public.handle_evidence_timeout_confirmed() IS 'Handles evidence timeout confirmation by referee. Request/task closure is handled by separate triggers.';
```

Key changes: Renamed function, removed references to `NEW.task_id` and `NEW.referee_id` (these don't exist on the judgements table), simplified the body.

**Step 2: Commit**

```bash
git add -u supabase/schemas/judgement/functions/handle_evidence_timeout_confirmation.sql
git add supabase/schemas/judgement/functions/handle_evidence_timeout_confirmed.sql
git commit -m "refactor(supabase): rename handle_evidence_timeout_confirmed

Rename from handle_evidence_timeout_confirmation. Simplify body
and fix references to non-existent columns."
```

---

### Task 8: Function - auto_score_timeout_referee

**Files:**
- Modify: `supabase/schemas/matching/functions/auto_score_timeout_referee.sql`

**Step 1: Update for binary rating**

Replace the entire file with:

```sql
CREATE OR REPLACE FUNCTION public.auto_score_timeout_referee() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
BEGIN
    -- Only process when is_confirmed changes from false to true
    IF TG_OP = 'UPDATE' AND OLD.is_confirmed = false AND NEW.is_confirmed = true THEN

        -- Get the judgement details with task info
        SELECT
            j.id,
            trr.matched_referee_id AS referee_id,
            j.status,
            t.tasker_id
        INTO v_judgement
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        WHERE j.id = NEW.id;

        -- If this is a review_timeout confirmation, automatically score referee negatively
        IF v_judgement.status = 'review_timeout' THEN
            INSERT INTO public.rating_histories (
                rater_id,
                ratee_id,
                judgement_id,
                rating_type,
                is_positive,
                comment
            ) VALUES (
                v_judgement.tasker_id,
                v_judgement.referee_id,
                v_judgement.id,
                'referee',
                false,
                'Automatic negative rating due to referee timeout'
            ) ON CONFLICT (judgement_id, rating_type) DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.auto_score_timeout_referee() OWNER TO postgres;

COMMENT ON FUNCTION public.auto_score_timeout_referee() IS 'Automatically scores referee negatively when a review_timeout is confirmed. Inserts into rating_histories with is_positive=false.';
```

Key changes:
- `rating = 0` -> `is_positive = false`
- Removed `task_id` from INSERT
- `ON CONFLICT` updated to match new unique constraint `(judgement_id, rating_type)`
- Changed status check from `judgement_timeout` to `review_timeout` (matching the enum)
- Removed `RAISE NOTICE`

**Step 2: Commit**

```bash
git add supabase/schemas/matching/functions/auto_score_timeout_referee.sql
git commit -m "refactor(supabase): update auto_score_timeout_referee for binary rating

Use is_positive=false instead of rating=0. Remove task_id column
reference. Update ON CONFLICT to (judgement_id, rating_type)."
```

---

### Task 9: Triggers - close flow restructure

**Files:**
- Delete: `supabase/schemas/judgement/triggers/on_judgements_confirmed_close_task.sql`
- Delete: `supabase/schemas/task/functions/close_task_if_all_judgements_confirmed.sql`
- Create: `supabase/schemas/judgement/triggers/on_judgement_confirmed_close_request.sql`
- Create: `supabase/schemas/task/triggers/on_all_requests_closed_close_task.sql`

**Step 1: Delete old files**

```bash
rm supabase/schemas/judgement/triggers/on_judgements_confirmed_close_task.sql
rm supabase/schemas/task/functions/close_task_if_all_judgements_confirmed.sql
```

**Step 2: Create on_judgement_confirmed_close_request.sql**

Create `supabase/schemas/judgement/triggers/on_judgement_confirmed_close_request.sql`:

```sql
-- Function + Trigger: Close referee request when judgement is confirmed
CREATE OR REPLACE FUNCTION public.close_referee_request_on_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.close_referee_request_on_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_judgement_confirmed_close_request
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (
        (NEW.is_confirmed = true AND OLD.is_confirmed = false)
        OR (NEW.is_evidence_timeout_confirmed = true AND OLD.is_evidence_timeout_confirmed = false)
    )
    EXECUTE FUNCTION public.close_referee_request_on_confirmed();
```

**Step 3: Create on_all_requests_closed_close_task.sql**

Create `supabase/schemas/task/triggers/on_all_requests_closed_close_task.sql`:

```sql
-- Function + Trigger: Close task when all referee requests are closed
CREATE OR REPLACE FUNCTION public.close_task_if_all_requests_closed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_task_id uuid;
BEGIN
    v_task_id := NEW.task_id;

    -- Concurrency protection: lock the task row
    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    -- Check if all referee requests for this task are closed
    IF NOT EXISTS (
        SELECT 1 FROM public.task_referee_requests
        WHERE task_id = v_task_id AND status != 'closed'::public.referee_request_status
    ) THEN
        UPDATE public.tasks
        SET status = 'closed'::public.task_status
        WHERE id = v_task_id;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.close_task_if_all_requests_closed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_all_requests_closed_close_task
    AFTER UPDATE ON public.task_referee_requests
    FOR EACH ROW
    WHEN (NEW.status = 'closed' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.close_task_if_all_requests_closed();
```

**Step 4: Commit**

```bash
git add -u supabase/schemas/judgement/triggers/on_judgements_confirmed_close_task.sql supabase/schemas/task/functions/close_task_if_all_judgements_confirmed.sql
git add supabase/schemas/judgement/triggers/on_judgement_confirmed_close_request.sql supabase/schemas/task/triggers/on_all_requests_closed_close_task.sql
git commit -m "refactor(supabase): restructure close flow to 2-step process

Replace direct judgement->task close with:
1. on_judgement_confirmed_close_request: judgement confirmed -> request closed
2. on_all_requests_closed_close_task: all requests closed -> task closed

This matches the lifecycle: judgement confirmed -> referee_request
closed -> (all closed) -> task closed."
```

---

### Task 10: Trigger updates - handle_judgement_confirmed and evidence_timeout

**Files:**
- Modify: `supabase/schemas/judgement/triggers/on_judgements_evidence_timeout_close_referee_request.sql`
- Modify: `supabase/schemas/judgement/triggers/on_judgements_timeout_score_referee.sql`

**Step 1: Update on_judgements_evidence_timeout_close_referee_request.sql**

Replace with:

```sql
CREATE OR REPLACE TRIGGER on_judgements_evidence_timeout_confirmed
AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmed();

COMMENT ON TRIGGER on_judgements_evidence_timeout_confirmed ON public.judgements IS 'Trigger that fires when evidence timeout is confirmed by referee';
```

Note: Renamed trigger and updated to call renamed function. The actual closing of referee_request is now handled by `on_judgement_confirmed_close_request` trigger (Task 9).

**Step 2: Update on_judgements_timeout_score_referee.sql (no change needed)**

The trigger definition is fine as-is. The function it calls (`auto_score_timeout_referee`) was updated in Task 8.

**Step 3: Create missing trigger for handle_judgement_confirmed**

Create `supabase/schemas/judgement/triggers/on_judgement_confirmed.sql`:

```sql
CREATE OR REPLACE TRIGGER on_judgement_confirmed
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = false))
    EXECUTE FUNCTION public.handle_judgement_confirmed();
```

Note: This trigger existed in the init migration but was missing from schemas/triggers. Creating it with the correct function reference.

**Step 4: Commit**

```bash
git add supabase/schemas/judgement/triggers/on_judgements_evidence_timeout_close_referee_request.sql
git add supabase/schemas/judgement/triggers/on_judgement_confirmed.sql
git commit -m "refactor(supabase): update triggers for renamed functions

Rename evidence_timeout trigger to on_judgements_evidence_timeout_confirmed.
Add missing on_judgement_confirmed trigger definition for
handle_judgement_confirmed function."
```

---

### Task 11: RLS policy - rating_histories

**Files:**
- Modify: `supabase/schemas/rating/policies/rating_histories_policies.sql`

**Step 1: Update SELECT policy to use judgement_id JOIN**

Replace the entire file with:

```sql
ALTER TABLE public.rating_histories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Rating Histories: insert if authenticated" ON public.rating_histories
FOR INSERT TO authenticated
WITH CHECK (true);

CREATE POLICY "Rating Histories: select if task participant" ON public.rating_histories
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.task_referee_requests trr
        JOIN public.tasks t ON t.id = trr.task_id
        WHERE trr.id = rating_histories.judgement_id
        AND (
            t.tasker_id = (SELECT auth.uid())
            OR trr.matched_referee_id = (SELECT auth.uid())
        )
    )
);
```

Key change: Replaced `task_id`-based lookups with `judgement_id -> task_referee_requests` JOIN.

**Step 2: Commit**

```bash
git add supabase/schemas/rating/policies/rating_histories_policies.sql
git commit -m "refactor(supabase): update rating_histories RLS for judgement_id

Replace task_id-based access check with judgement_id JOIN through
task_referee_requests, since task_id column was removed."
```

---

### Task 12: config.toml updates

**Files:**
- Modify: `supabase/config.toml`

**Step 1: Update schema file references**

Apply these changes to `supabase/config.toml`:

1. In the `# rating` functions section (~line 124-126): Remove `set_rater_id.sql` reference
2. In the `# judgement` functions section (~line 128-133): Update function filenames
3. In the `# task` section (~line 103-104): Replace `close_task_if_all_judgements_confirmed.sql`
4. In the `# Judgement` triggers section (~line 158-164): Update trigger filenames
5. In the `# Task` triggers section (~line 166-167): Add new trigger file
6. In the `# Rating` triggers section (~line 194-197): Remove `set_rater_id` trigger

Specific changes:

```
# rating functions: remove set_rater_id.sql line
- "./schemas/rating/functions/set_rater_id.sql",

# judgement functions: update names
- "./schemas/judgement/functions/handle_evidence_timeout_confirmation.sql",
- "./schemas/judgement/functions/handle_judgement_confirmation.sql",
+ "./schemas/judgement/functions/handle_evidence_timeout_confirmed.sql",
+ "./schemas/judgement/functions/handle_judgement_confirmed.sql",

# task functions: remove old, handled by trigger file now
- "./schemas/task/functions/close_task_if_all_judgements_confirmed.sql",

# judgement triggers: update
- "./schemas/judgement/triggers/on_judgements_confirmed_close_task.sql",
+ "./schemas/judgement/triggers/on_judgement_confirmed_close_request.sql",
+ "./schemas/judgement/triggers/on_judgement_confirmed.sql",

# evidence_timeout trigger name stays the same file path but content changed (handled already)

# task triggers: add new
+ "./schemas/task/triggers/on_all_requests_closed_close_task.sql",

# rating triggers: remove set_rater_id
- "./schemas/rating/triggers/on_rating_histories_insert_set_rater_id.sql",
```

**Step 2: Commit**

```bash
git add supabase/config.toml
git commit -m "chore(supabase): update config.toml for renamed and new schema files

Update file references for renamed functions, removed set_rater_id,
new close-flow triggers, and removed old close_task trigger."
```

---

### Task 13: Migration file

**Files:**
- Create: `supabase/migrations/YYYYMMDDHHMMSS_add_confirm_judgement_and_binary_rating.sql`

**Step 1: Generate migration timestamp and create file**

```bash
npx supabase migration new add_confirm_judgement_and_binary_rating
```

**Step 2: Write migration content**

The migration should apply all changes in order. Since `supabase db reset` can be used, this migration mainly serves as documentation and for future environments.

```sql
-- Migration: Confirm Judgement & Binary Rating
-- Design: docs/plans/2026-02-14-confirm-judgement-design.md

-- 1. Create rating_type enum
CREATE TYPE public.rating_type AS ENUM ('tasker', 'referee');

-- 2. Migrate rating_histories table
ALTER TABLE public.rating_histories
    ADD COLUMN is_positive boolean;

-- Backfill existing data (dev only)
UPDATE public.rating_histories SET is_positive = (rating >= 3) WHERE is_positive IS NULL;

ALTER TABLE public.rating_histories
    ALTER COLUMN is_positive SET NOT NULL,
    DROP COLUMN rating,
    DROP COLUMN task_id,
    ALTER COLUMN judgement_id SET NOT NULL;

-- Change rating_type from text to enum
ALTER TABLE public.rating_histories
    ALTER COLUMN rating_type TYPE public.rating_type USING rating_type::public.rating_type;

-- Update constraints
ALTER TABLE public.rating_histories DROP CONSTRAINT IF EXISTS rating_histories_rating_type_check;
ALTER TABLE public.rating_histories DROP CONSTRAINT IF EXISTS unique_rating_per_judgement;
ALTER TABLE public.rating_histories ADD CONSTRAINT unique_rating_per_judgement UNIQUE (judgement_id, rating_type);

-- Update indexes
DROP INDEX IF EXISTS idx_rating_histories_task_id;
DROP INDEX IF EXISTS idx_rating_histories_user_id;
DROP INDEX IF EXISTS idx_rating_histories_user_type;
CREATE INDEX IF NOT EXISTS idx_rating_histories_ratee_id ON public.rating_histories USING btree (ratee_id);
CREATE INDEX IF NOT EXISTS idx_rating_histories_ratee_type ON public.rating_histories USING btree (ratee_id, rating_type);

-- 3. Migrate user_ratings table
ALTER TABLE public.user_ratings
    DROP COLUMN tasker_rating,
    DROP COLUMN tasker_rating_count,
    DROP COLUMN referee_rating,
    DROP COLUMN referee_rating_count,
    ADD COLUMN tasker_positive_count integer DEFAULT 0,
    ADD COLUMN tasker_total_count integer DEFAULT 0,
    ADD COLUMN tasker_positive_pct numeric DEFAULT 0,
    ADD COLUMN referee_positive_count integer DEFAULT 0,
    ADD COLUMN referee_total_count integer DEFAULT 0,
    ADD COLUMN referee_positive_pct numeric DEFAULT 0;

-- 4. Drop set_rater_id trigger and function
DROP TRIGGER IF EXISTS on_rating_histories_insert_set_rater_id ON public.rating_histories;
DROP FUNCTION IF EXISTS public.set_rater_id();

-- 5. Replace update_user_ratings function
CREATE OR REPLACE FUNCTION public.update_user_ratings() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    affected_user_id uuid;
    v_positive integer;
    v_total integer;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.ratee_id;
    ELSE
        affected_user_id := NEW.ratee_id;
    END IF;

    SELECT COUNT(*) FILTER (WHERE is_positive = true), COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'tasker';

    UPDATE public.user_ratings SET
        tasker_positive_count = v_positive,
        tasker_total_count = v_total,
        tasker_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    SELECT COUNT(*) FILTER (WHERE is_positive = true), COUNT(*)
    INTO v_positive, v_total
    FROM public.rating_histories
    WHERE ratee_id = affected_user_id AND rating_type = 'referee';

    UPDATE public.user_ratings SET
        referee_positive_count = v_positive,
        referee_total_count = v_total,
        referee_positive_pct = CASE WHEN v_total > 0 THEN ROUND(v_positive::numeric / v_total * 100, 1) ELSE 0 END,
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$;

-- 6. Replace confirm_judgement_and_rate_referee RPC
DROP FUNCTION IF EXISTS public.confirm_judgement_and_rate_referee(uuid, uuid, uuid, integer, text);

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
BEGIN
    SELECT j.id, j.status, j.is_confirmed, trr.task_id, trr.matched_referee_id AS referee_id, t.tasker_id
    INTO v_judgement
    FROM public.judgements j
    JOIN public.task_referee_requests trr ON trr.id = j.id
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE j.id = p_judgement_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Judgement not found'; END IF;
    IF v_judgement.tasker_id != (SELECT auth.uid()) THEN RAISE EXCEPTION 'Only the tasker can confirm a judgement'; END IF;
    IF v_judgement.status NOT IN ('approved', 'rejected') THEN RAISE EXCEPTION 'Judgement must be in approved or rejected status to confirm'; END IF;
    IF v_judgement.is_confirmed = TRUE THEN RETURN; END IF;

    INSERT INTO public.rating_histories (judgement_id, ratee_id, rater_id, rating_type, is_positive, comment)
    VALUES (p_judgement_id, v_judgement.referee_id, (SELECT auth.uid()), 'referee', p_is_positive, p_comment);

    UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    IF v_rows_affected = 0 THEN RAISE EXCEPTION 'Failed to update judgement confirmation status'; END IF;
END;
$$;

-- 7. Replace handle_judgement_confirmed function
DROP FUNCTION IF EXISTS public.handle_judgement_confirmation() CASCADE;

CREATE OR REPLACE FUNCTION public.handle_judgement_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
BEGIN
    IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
        IF NEW.status IN ('approved', 'rejected') THEN
            SELECT trr.matched_referee_id, trr.task_id, t.title
            INTO v_referee_id, v_task_id, v_task_title
            FROM public.task_referee_requests trr
            JOIN public.tasks t ON t.id = trr.task_id
            WHERE trr.id = NEW.id;

            IF FOUND THEN
                PERFORM public.notify_event(
                    v_referee_id,
                    'notification_judgement_confirmed',
                    ARRAY[v_task_title],
                    jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- Create trigger for handle_judgement_confirmed
DROP TRIGGER IF EXISTS on_judgement_confirmed ON public.judgements;
CREATE TRIGGER on_judgement_confirmed
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = false))
    EXECUTE FUNCTION public.handle_judgement_confirmed();

-- 8. Replace handle_evidence_timeout_confirmed function
DROP FUNCTION IF EXISTS public.handle_evidence_timeout_confirmation() CASCADE;

CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    IF NEW.is_evidence_timeout_confirmed = true
       AND OLD.is_evidence_timeout_confirmed = false
       AND NEW.status = 'evidence_timeout' THEN
        NULL;
    END IF;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in handle_evidence_timeout_confirmed: %', SQLERRM;
        RETURN NEW;
END;
$$;

-- Update evidence timeout trigger
DROP TRIGGER IF EXISTS on_judgements_evidence_timeout_close_referee_request ON public.judgements;
CREATE TRIGGER on_judgements_evidence_timeout_confirmed
    AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
    FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmed();

-- 9. Replace auto_score_timeout_referee function
CREATE OR REPLACE FUNCTION public.auto_score_timeout_referee() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_judgement RECORD;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.is_confirmed = false AND NEW.is_confirmed = true THEN
        SELECT j.id, trr.matched_referee_id AS referee_id, j.status, t.tasker_id
        INTO v_judgement
        FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        JOIN public.tasks t ON trr.task_id = t.id
        WHERE j.id = NEW.id;

        IF v_judgement.status = 'review_timeout' THEN
            INSERT INTO public.rating_histories (rater_id, ratee_id, judgement_id, rating_type, is_positive, comment)
            VALUES (v_judgement.tasker_id, v_judgement.referee_id, v_judgement.id, 'referee', false, 'Automatic negative rating due to referee timeout')
            ON CONFLICT (judgement_id, rating_type) DO NOTHING;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- 10. Restructure close flow: 2-step process

-- Drop old trigger
DROP TRIGGER IF EXISTS on_judgements_confirmed_close_task ON public.judgements;
DROP FUNCTION IF EXISTS public.close_task_if_all_judgements_confirmed();

-- Step 1: Judgement confirmed -> close referee request
CREATE OR REPLACE FUNCTION public.close_referee_request_on_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_judgement_confirmed_close_request
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (
        (NEW.is_confirmed = true AND OLD.is_confirmed = false)
        OR (NEW.is_evidence_timeout_confirmed = true AND OLD.is_evidence_timeout_confirmed = false)
    )
    EXECUTE FUNCTION public.close_referee_request_on_confirmed();

-- Step 2: All requests closed -> close task
CREATE OR REPLACE FUNCTION public.close_task_if_all_requests_closed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_task_id uuid;
BEGIN
    v_task_id := NEW.task_id;
    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1 FROM public.task_referee_requests
        WHERE task_id = v_task_id AND status != 'closed'::public.referee_request_status
    ) THEN
        UPDATE public.tasks SET status = 'closed'::public.task_status WHERE id = v_task_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_all_requests_closed_close_task
    AFTER UPDATE ON public.task_referee_requests
    FOR EACH ROW
    WHEN (NEW.status = 'closed' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.close_task_if_all_requests_closed();

-- 11. Update RLS policy for rating_histories
DROP POLICY IF EXISTS "Rating Histories: select if task participant" ON public.rating_histories;
CREATE POLICY "Rating Histories: select if task participant" ON public.rating_histories
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.task_referee_requests trr
        JOIN public.tasks t ON t.id = trr.task_id
        WHERE trr.id = rating_histories.judgement_id
        AND (
            t.tasker_id = (SELECT auth.uid())
            OR trr.matched_referee_id = (SELECT auth.uid())
        )
    )
);
```

**Step 3: Commit**

```bash
git add supabase/migrations/*_add_confirm_judgement_and_binary_rating.sql
git commit -m "feat(supabase): add migration for confirm judgement and binary rating

Single migration covering: binary rating schema, confirm RPC update,
close-flow restructure, notification addition, and RLS policy update."
```

---

### Task 14: Test - confirm_judgement_and_rate_referee

**Files:**
- Create: `supabase/tests/test_confirm_judgement.sql`

**Step 1: Write test file**

Follow the pattern from `supabase/tests/test_judge_evidence.sql`:

```sql
-- =============================================================================
-- Test: confirm_judgement_and_rate_referee RPC
--
-- Usage:
--   docker cp supabase/tests/test_confirm_judgement.sql supabase_db_supabase:/tmp/ && \
--   docker exec supabase_db_supabase psql -U postgres -f /tmp/test_confirm_judgement.sql
--
-- All test data is created inside a transaction and rolled back at the end.
-- =============================================================================

\set ON_ERROR_STOP on
\echo '=========================================='
\echo ' Test: confirm_judgement_and_rate_referee'
\echo '=========================================='

BEGIN;

-- ===== Setup =====
\echo ''
\echo '[Setup] Creating test users...'

INSERT INTO auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

\echo '[Setup] Creating task...'

INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Task', 'Test description', 'Test criteria', now() + interval '7 days', 'open');

\echo '[Setup] Creating referee request...'

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

\echo '[Setup] Creating judgement (approved)...'

INSERT INTO public.judgements (id, status)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'approved');


-- ===== Test 1: Confirm approved judgement with positive rating =====
\echo ''
\echo '=========================================='
\echo ' Test 1: Confirm approved (positive rating)'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  true,
  'Great referee!'
);

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = true,
    'Test 1 FAILED: judgement should be confirmed';
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = true,
    'Test 1 FAILED: rating should be positive';
  ASSERT (SELECT rater_id FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = '11111111-1111-1111-1111-111111111111'::uuid,
    'Test 1 FAILED: rater_id should be tasker';
  ASSERT (SELECT ratee_id FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = '22222222-2222-2222-2222-222222222222'::uuid,
    'Test 1 FAILED: ratee_id should be referee';
  ASSERT (SELECT comment FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = 'Great referee!',
    'Test 1 FAILED: comment mismatch';
  RAISE NOTICE 'Test 1 PASSED: confirm approved with positive rating';
END $$;


-- ===== Test 2: Idempotency - confirming again does nothing =====
\echo ''
\echo '=========================================='
\echo ' Test 2: Idempotency'
\echo '=========================================='

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

-- Should not raise error
SELECT public.confirm_judgement_and_rate_referee(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  false,
  'Changed my mind'
);

DO $$
BEGIN
  -- Rating should still be the original positive one
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND rating_type = 'referee') = true,
    'Test 2 FAILED: rating should still be positive (idempotency)';
  ASSERT (SELECT COUNT(*) FROM public.rating_histories WHERE judgement_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 1,
    'Test 2 FAILED: should still have exactly 1 rating';
  RAISE NOTICE 'Test 2 PASSED: idempotency works';
END $$;


-- ===== Test 3: Confirm rejected judgement with negative rating =====
\echo ''
\echo '=========================================='
\echo ' Test 3: Confirm rejected (negative rating)'
\echo '=========================================='

-- Reset: create new judgement for a different request
INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'rejected');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  false,
  'Review was unfair'
);

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') = true,
    'Test 3 FAILED: judgement should be confirmed';
  ASSERT (SELECT is_positive FROM public.rating_histories WHERE judgement_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND rating_type = 'referee') = false,
    'Test 3 FAILED: rating should be negative';
  RAISE NOTICE 'Test 3 PASSED: confirm rejected with negative rating';
END $$;


-- ===== Test 4: Non-tasker cannot confirm =====
\echo ''
\echo '=========================================='
\echo ' Test 4: Non-tasker cannot confirm'
\echo '=========================================='

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'approved');

-- Set JWT to referee (not the tasker)
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

DO $$
BEGIN
  PERFORM public.confirm_judgement_and_rate_referee(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    true,
    'Trying as referee'
  );
  RAISE NOTICE 'Test 4 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Only the tasker can confirm a judgement' THEN
      RAISE NOTICE 'Test 4 PASSED: non-tasker blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 4 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 5: Cannot confirm in_review status =====
\echo ''
\echo '=========================================='
\echo ' Test 5: Cannot confirm in_review'
\echo '=========================================='

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'in_review');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

DO $$
BEGIN
  PERFORM public.confirm_judgement_and_rate_referee(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    true,
    'Trying to confirm in_review'
  );
  RAISE NOTICE 'Test 5 FAILED: should have raised exception';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM = 'Judgement must be in approved or rejected status to confirm' THEN
      RAISE NOTICE 'Test 5 PASSED: in_review blocked (error: %)', SQLERRM;
    ELSE
      RAISE NOTICE 'Test 5 FAILED: unexpected error: %', SQLERRM;
    END IF;
END $$;


-- ===== Test 6: Close flow - confirm triggers request close =====
\echo ''
\echo '=========================================='
\echo ' Test 6: Confirm triggers request close'
\echo '=========================================='

DO $$
BEGIN
  -- Check that the referee request for test 1 was closed by trigger
  ASSERT (SELECT status FROM public.task_referee_requests WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 'closed',
    'Test 6 FAILED: referee request should be closed after confirm';
  RAISE NOTICE 'Test 6 PASSED: request closed on confirm';
END $$;


-- ===== Test 7: Close flow - all confirmed closes task =====
\echo ''
\echo '=========================================='
\echo ' Test 7: All confirmed closes task'
\echo '=========================================='

-- Confirm remaining unconfirmed judgements to close the task
-- dddddddd is still unconfirmed (test 4 failed to confirm), confirm it now
SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  true,
  'Good job'
);

-- eeeeeeee is in_review, approve then confirm
SELECT set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
SELECT public.judge_evidence('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'approved', 'Approving');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
SELECT public.confirm_judgement_and_rate_referee(
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  true,
  'Also good'
);

DO $$
BEGIN
  -- All 4 requests (bb, cc, dd, ee) should be closed, so task should be closed
  ASSERT (SELECT status FROM public.tasks WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'closed',
    'Test 7 FAILED: task should be closed when all requests are closed';
  RAISE NOTICE 'Test 7 PASSED: task closed when all requests closed';
END $$;


-- ===== Test 8: Confirm without comment =====
\echo ''
\echo '=========================================='
\echo ' Test 8: Confirm without comment'
\echo '=========================================='

-- Create fresh task and judgement
INSERT INTO public.tasks (id, tasker_id, title, description, criteria, due_date, status)
VALUES ('ffffffff-ffff-ffff-ffff-ffffffffffff', '11111111-1111-1111-1111-111111111111', 'Task 2', 'Desc', 'Criteria', now() + interval '7 days', 'open');

INSERT INTO public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, responded_at)
VALUES ('99999999-9999-9999-9999-999999999999', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now());

INSERT INTO public.judgements (id, status)
VALUES ('99999999-9999-9999-9999-999999999999', 'approved');

SELECT set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

SELECT public.confirm_judgement_and_rate_referee(
  '99999999-9999-9999-9999-999999999999',
  true
);

DO $$
BEGIN
  ASSERT (SELECT is_confirmed FROM public.judgements WHERE id = '99999999-9999-9999-9999-999999999999') = true,
    'Test 8 FAILED: should confirm without comment';
  ASSERT (SELECT comment FROM public.rating_histories WHERE judgement_id = '99999999-9999-9999-9999-999999999999') IS NULL,
    'Test 8 FAILED: comment should be NULL';
  RAISE NOTICE 'Test 8 PASSED: confirm without comment works';
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
git add supabase/tests/test_confirm_judgement.sql
git commit -m "test(supabase): add tests for confirm_judgement_and_rate_referee

Tests cover: positive/negative rating, idempotency, non-tasker
rejection, invalid status rejection, close flow (request + task),
and confirm without comment."
```

---

### Task 15: Verify with supabase db reset

**Step 1: Run db reset to verify all schemas load correctly**

```bash
cd supabase && npx supabase db reset
```

Expected: Clean reset with no errors.

**Step 2: Run tests**

```bash
docker cp supabase/tests/test_confirm_judgement.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_confirm_judgement.sql
```

Expected: All 8 tests pass.

**Step 3: Also verify existing test still passes**

```bash
docker cp supabase/tests/test_judge_evidence.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_judge_evidence.sql
```

Expected: All 7 tests pass.

**Step 4: Run supabase db diff to check for drift**

```bash
npx supabase db diff
```

Expected: No unexpected diff (or only expected differences from views etc.).
