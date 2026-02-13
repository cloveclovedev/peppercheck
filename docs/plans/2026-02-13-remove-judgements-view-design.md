# Remove judgements_view Refactoring Design

## Background

`judgements_view` is a PostgreSQL view that augments the `judgements` table with `task_id`, `referee_id`, and a computed `can_reopen` field via JOINs.

The view causes `supabase db diff` to generate a migration on every run, degrading the development experience.

## Approach

Inline the view logic into the dependent SQL functions and drop the view entirely.

## Changes

### 1. Modify `get_active_referee_tasks.sql`

**Current**: Uses `LEFT JOIN public.judgements_view AS j ON trr.id = j.id` and returns `to_jsonb(j)` as the judgement object.

**Updated**:
- Replace with direct LEFT JOIN on `judgements` table
- Replace `to_jsonb(j)` with explicit `jsonb_build_object` including inline `can_reopen` calculation

```sql
LEFT JOIN public.judgements AS j ON trr.id = j.id
```

Judgement object built explicitly:
```sql
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
    'can_reopen', (j.status = 'rejected'
      AND j.reopen_count < 1
      AND t.due_date > now()
      AND EXISTS (
        SELECT 1 FROM public.task_evidences te
        WHERE te.task_id = trr.task_id
          AND te.updated_at > j.updated_at
      ))
  )
ELSE NULL END
```

### 2. Modify `reopen_judgement.sql`

**Current**: Selects `task_id` and `can_reopen` from `judgements_view`.

**Updated**: Direct table JOINs with inline `can_reopen` computation:
```sql
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
```

### 3. Delete view definition file

- Remove `supabase/schemas/judgement/views/judgements_view.sql`

### 4. Create migration

A single migration that:
1. `CREATE OR REPLACE` the `get_active_referee_tasks` function
2. `CREATE OR REPLACE` the `reopen_judgement` function
3. `DROP VIEW IF EXISTS public.judgements_view`

### Unchanged

- Past migration files (preserved as history)
- Flutter/Dart code (no direct dependency on the view)

## Design Decisions

### Why compute `can_reopen` server-side

- `reopen_judgement` validates the same logic server-side, so keeping it as a DB-computed value ensures the UI display and server validation stay in sync (Single Source of Truth)
- `now()` is evaluated using server time, avoiding device timezone inconsistencies
- JOIN-based subquery computes efficiently in the database

### Why inline rather than extract a helper function

- Only 2 call sites use `can_reopen`
- The logic is simple (4-condition AND)
- Avoids additional function management overhead
