# Home Screen Task Card Ordering

**Date:** 2026-05-04

## Problem

The home screen lists tasks in an order that does not reflect urgency:

- **Your Tasks** (`activeUserTasksProvider`) is sorted by `created_at DESC` (newest first), so a task due tomorrow can sit below a freshly created draft.
- **Referee Tasks** (`activeRefereeTasksProvider`) has no `ORDER BY` in the RPC, so the order is undefined and may change between calls.

The `tasks.due_date` column already exists on every task and is the natural signal for "what should I look at next?". It is currently used only for display in `TaskCard`.

## Design

### Sort rule (applied to both sections)

```
1. due_date IS NOT NULL → ascending by due_date (closest first; past-due tasks naturally float to the top)
2. due_date IS NULL     → ascending by created_at (oldest drafts first)
3. NULL bucket sits below the non-NULL bucket
```

Tie-break inside each bucket is `created_at ASC`.

### Why this rule

- The user's mental model on home is "what is most urgent". Soonest `due_date` matches that.
- Past-due (overdue) tasks have the smallest `due_date` value, so ascending order surfaces them first without a separate code path.
- For drafts (`due_date` is currently only NULL on tasker-side drafts), older drafts float higher because they have been sitting unattended longest. Pushing them below scheduled tasks keeps the "next action" focus near the top.

### Implementation

**1. Your Tasks — DB query (`task_repository.dart:103`)**

Replace the single `.order('created_at', ascending: false)` with a chained order:

```dart
.order('due_date', ascending: true, nullsFirst: false)
.order('created_at', ascending: true)
```

`nullsFirst: false` puts NULL `due_date` rows at the bottom; the second `.order()` becomes the tie-breaker.

**2. Referee Tasks — RPC function (`get_active_referee_tasks.sql`)**

Add an `ORDER BY` inside the `jsonb_agg(...)`:

```sql
jsonb_agg(
  jsonb_build_object(...)
  ORDER BY t.due_date ASC NULLS LAST, t.created_at ASC
)
```

Generate the migration with `supabase db diff -f reorder_active_referee_tasks_by_due_date` and review before commit.

### Tests

- **pgTAP test (`supabase/tests/database/`)**: insert a fixture set with mixed `due_date` values (past, near, far, NULL) and assert that `get_active_referee_tasks` returns them in the expected order, including the `created_at` tie-break.
- **Flutter side**: no new automated test. Verified manually on emulator at the integration step (per the consolidated emulator verification policy).

### Files changed

```
peppercheck_flutter/
  lib/features/task/data/task_repository.dart        # MODIFY: chain order by due_date then created_at

supabase/
  schemas/matching/functions/get_active_referee_tasks.sql  # MODIFY: ORDER BY inside jsonb_agg
  migrations/<generated>_reorder_active_referee_tasks_by_due_date.sql  # NEW: auto-generated
  tests/database/<new>.sql                           # NEW: pgTAP coverage for ordering
```

### Out of scope

- Adding a UI affordance for overdue tasks (e.g., red badge).
- Re-ordering other task lists (task detail, evidence list, payouts).
- Letting users pick a sort order.
- Backfilling `due_date` on legacy NULL rows.
