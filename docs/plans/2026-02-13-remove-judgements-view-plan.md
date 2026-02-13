# Remove judgements_view Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the `judgements_view` PostgreSQL view that causes spurious `supabase db diff` migrations, inlining its logic into dependent functions.

**Architecture:** Modify two SQL functions (`get_active_referee_tasks`, `reopen_judgement`) to use direct table JOINs with inline `can_reopen` calculation instead of the view. Then delete the view definition and generate a migration via `supabase db diff`.

**Tech Stack:** PostgreSQL, Supabase CLI

---

### Task 1: Modify `get_active_referee_tasks` function

**Files:**
- Modify: `supabase/schemas/matching/functions/get_active_referee_tasks.sql`

**Step 1: Replace view JOIN with direct table JOIN and inline can_reopen**

Replace the full content of `supabase/schemas/matching/functions/get_active_referee_tasks.sql` with:

```sql
CREATE OR REPLACE FUNCTION public.get_active_referee_tasks() RETURNS jsonb
    LANGUAGE sql
    SET search_path = ''
    AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'task', to_jsonb(t),
        'judgement', CASE WHEN j.id IS NOT NULL THEN
          jsonb_build_object(
            'id', j.id,
            'comment', j.comment,
            'status', j.status,
            'created_at', j.created_at,
            'updated_at', j.updated_at,
            'is_confirmed', j.is_confirmed,
            'reopen_count', j.reopen_count,
            'is_evidence_timeout_confirmed', j.is_evidence_timeout_confirmed,
            'can_reopen', (
              j.status = 'rejected'
              AND j.reopen_count < 1
              AND t.due_date > now()
              AND EXISTS (
                SELECT 1 FROM public.task_evidences te
                WHERE te.task_id = trr.task_id
                  AND te.updated_at > j.updated_at
              )
            )
          )
        ELSE NULL END,
        'tasker_profile', to_jsonb(p)
      )
    ),
    '[]'::jsonb
  )
  FROM
    public.task_referee_requests AS trr
  INNER JOIN
    public.tasks AS t ON trr.task_id = t.id
  LEFT JOIN
    public.judgements AS j ON trr.id = j.id
  INNER JOIN
    public.profiles AS p ON t.tasker_id = p.id
  WHERE
    trr.matched_referee_id = auth.uid()
    AND trr.status IN ('matched', 'accepted');
$$;

ALTER FUNCTION public.get_active_referee_tasks() OWNER TO postgres;
```

**Step 2: Commit**

```bash
git add supabase/schemas/matching/functions/get_active_referee_tasks.sql
git commit -m "refactor(supabase): inline judgements_view into get_active_referee_tasks"
```

---

### Task 2: Modify `reopen_judgement` function

**Files:**
- Modify: `supabase/schemas/judgement/functions/reopen_judgement.sql`

**Step 1: Replace view query with direct table JOINs**

Replace the full content of `supabase/schemas/judgement/functions/reopen_judgement.sql` with:

```sql
CREATE OR REPLACE FUNCTION public.reopen_judgement(p_judgement_id uuid) RETURNS void
    LANGUAGE plpgsql
    SET search_path = ''
    AS $$
DECLARE
  v_task_id uuid;
  v_can_reopen boolean;
BEGIN
  -- Get judgement details and can_reopen status via direct JOINs
  SELECT trr.task_id,
         (j.status = 'rejected'
          AND j.reopen_count < 1
          AND t.due_date > now()
          AND EXISTS (
            SELECT 1 FROM public.task_evidences te
            WHERE te.task_id = trr.task_id
              AND te.updated_at > j.updated_at
          ))
  INTO v_task_id, v_can_reopen
  FROM public.judgements j
  JOIN public.task_referee_requests trr ON j.id = trr.id
  JOIN public.tasks t ON trr.task_id = t.id
  WHERE j.id = p_judgement_id;

  -- Check if judgement exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Judgement not found';
  END IF;

  -- Security check: Only tasker can reopen their judgement
  IF NOT public.is_task_tasker(v_task_id, (SELECT auth.uid())) THEN
    RAISE EXCEPTION 'Only the task owner can request judgement reopening';
  END IF;

  -- Validation: can_reopen check (status=rejected, reopen_count<1, not past due, evidence updated)
  IF NOT v_can_reopen THEN
    RAISE EXCEPTION 'Judgement cannot be reopened. Check: status must be rejected, reopen count < 1, task not past due date, and evidence updated after judgement.';
  END IF;

  -- All validations passed - reopen the judgement
  UPDATE public.judgements
  SET
    status = 'awaiting_evidence',
    reopen_count = reopen_count + 1
  WHERE id = p_judgement_id;

END;
$$;

ALTER FUNCTION public.reopen_judgement(p_judgement_id uuid) OWNER TO postgres;
```

**Step 2: Commit**

```bash
git add supabase/schemas/judgement/functions/reopen_judgement.sql
git commit -m "refactor(supabase): inline judgements_view into reopen_judgement"
```

---

### Task 3: Delete view definition and remove views directory

**Files:**
- Delete: `supabase/schemas/judgement/views/judgements_view.sql`
- Delete: `supabase/schemas/judgement/views/` (directory, if empty after file removal)

**Step 1: Delete the view file and empty directory**

```bash
rm supabase/schemas/judgement/views/judgements_view.sql
rmdir supabase/schemas/judgement/views
```

**Step 2: Commit**

```bash
git add -A supabase/schemas/judgement/views/
git commit -m "refactor(supabase): delete judgements_view definition"
```

---

### Task 4: Generate and verify migration

**Step 1: Reset local database to apply current migrations**

```bash
supabase db reset
```

**Step 2: Generate migration with db diff**

```bash
supabase db diff -f remove_judgements_view
```

Expected output: A migration file containing:
- `CREATE OR REPLACE FUNCTION public.get_active_referee_tasks()` (updated)
- `CREATE OR REPLACE FUNCTION public.reopen_judgement()` (updated)
- `DROP VIEW IF EXISTS public.judgements_view`

**Step 3: Review the generated migration**

Read the generated migration file at `supabase/migrations/<timestamp>_remove_judgements_view.sql` and verify it contains exactly the expected changes — no more, no less.

**Step 4: Reset again to verify migration applies cleanly**

```bash
supabase db reset
```

Expected: No errors during migration application.

**Step 5: Verify db diff produces no further changes**

```bash
supabase db diff
```

Expected: Empty output (no diff). This confirms the view is no longer causing spurious migrations.

**Step 6: Commit the migration**

```bash
git add supabase/migrations/
git commit -m "refactor(supabase): add migration to remove judgements_view"
```

---

### Task 5: Run existing tests to verify no regressions

**Step 1: Run judge_evidence tests**

```bash
docker cp supabase/tests/test_judge_evidence.sql supabase_db_supabase:/tmp/ && \
docker exec supabase_db_supabase psql -U postgres -f /tmp/test_judge_evidence.sql
```

Expected: All 7 tests pass. These tests use `judge_evidence` RPC which operates on the same `judgements` and `task_referee_requests` tables. While they don't directly test the modified functions, they verify the underlying schema is intact.

**Step 2: Commit (no changes expected, verification only)**

No commit needed unless test fixes are required.
