# Referee Availability Enhancements Design

Date: 2026-02-23
Issue: #72

## Overview

Enhance the referee availability system with three capabilities:
1. Referee can cancel an accepted assignment (with automatic re-matching)
2. Referee can block specific date ranges from availability
3. System handles unmatched pending requests via cron retry and expiration with refund

## Time Constraint Model

```
|-------- 24h+ --------|-- 10h ----|-- 2h --|------ due_date ------|
^                       ^           ^        ^
Task Open             Re-match    Cancel   due_date
(open_deadline=24h)   cutoff      cutoff
                      (14h)       (12h)
```

**Rationale for 14h re-matching cutoff:** A referee assigned close to due_date may not notice the assignment (e.g., assigned at 2am for an 8am task). This is a human behavioral constraint (people sleep), not a technical limit. Even with a larger referee pool, this cutoff cannot be safely shortened.

**Rationale for 24h `open_deadline_hours`:** Ensures at least one full matching + cancellation + re-matching cycle can occur. The 24h constraint applies only to task "Open" (requesting a referee), not to task creation in draft status.

### Configuration: `matching_time_config` (typed singleton table)

All time constraint values are stored in a typed singleton table with CHECK constraints enforcing value interdependencies atomically. No hardcoded magic numbers.

```sql
CREATE TABLE public.matching_time_config (
    id boolean PRIMARY KEY DEFAULT true,
    open_deadline_hours int NOT NULL,           -- 24
    cancel_deadline_hours int NOT NULL,        -- 12
    rematch_cutoff_hours int NOT NULL,         -- 14
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT singleton CHECK (id = true),
    CONSTRAINT cancel_deadline_positive CHECK (cancel_deadline_hours > 0),
    CONSTRAINT ordering_invariant CHECK (
        open_deadline_hours > rematch_cutoff_hours
        AND rematch_cutoff_hours > cancel_deadline_hours
    )
);
```

The singleton pattern (`id boolean DEFAULT true CHECK (id = true)`) guarantees exactly one row. CHECK constraints enforce ordering invariants within a single transaction — no race conditions.

Functions read config with: `SELECT * INTO STRICT v_cfg FROM matching_time_config WHERE id = true;`

The existing `matching_config` table's `min_due_date_interval_hours` row is migrated to this table as `open_deadline_hours` and removed from `matching_config`.

Future config domains (review timeouts, auto-confirm delays) will get their own singleton tables following the same pattern.

---

## Feature 1: Referee Assignment Cancellation

### Approach

Cancel the current request and insert a new one. The existing INSERT trigger on `task_referee_requests` fires `process_matching` automatically, reusing the current matching infrastructure.

### Status Flow

```
pending → accepted (auto-match & auto-accept)
          ↓
          cancelled (referee cancels, 12h+ before due_date)
          ↓
          [new request: pending → accepted] (auto re-match, excluding cancelled referees)
```

### Enum Change

Add `cancelled` to `referee_request_status`. Distinct from `declined` (pre-acceptance rejection, currently unused but reserved for future opt-in matching).

### RPC: `cancel_referee_assignment`

**Caller:** Referee (authenticated via `auth.uid()`)

**Parameters:** `p_request_id uuid`

**Preconditions:**
1. Caller is the `matched_referee_id` on the request
2. Request status is `accepted`
3. `task.due_date - interval '<cancel_deadline_hours> hours' > NOW()` (read from `matching_time_config`)

**Processing:**
1. Set current request status to `cancelled`
2. Delete the associated judgement (status `awaiting_evidence` — no evidence submitted yet, safe to delete)
3. Insert new `task_referee_request` with same `task_id` and `matching_strategy`
4. INSERT trigger fires `process_matching` which:
   - Excludes the tasker
   - Excludes all `matched_referee_id` from cancelled requests for this task
   - Excludes referees blocked on the due_date via `referee_blocked_dates`
   - Applies standard availability + workload balancing
5. Notify based on result:
   - Match success: `notification_matching_reassigned_tasker` to tasker, `notification_task_assigned_referee` to new referee
   - Match failure: `notification_matching_cancelled_pending_tasker` to tasker, request stays `pending`

**Point handling:** No additional point lock needed. The original lock from `create_matching_request` persists across cancellation and re-matching.

---

## Feature 2: Blocked Dates

### Table: `referee_blocked_dates`

```sql
CREATE TABLE public.referee_blocked_dates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id),
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);
```

Separate from `referee_available_time_slots` because:
- Different data models: time_slots are recurring (day-of-week), blocked_dates are specific dates
- Different lifecycles: time_slots are long-lived, blocked_dates are temporary
- Simpler queries: matching checks availability AND not-blocked as two independent conditions

Single-day blocks: `start_date = end_date`. Multi-day blocks (e.g., vacation): date range.

### RLS

- SELECT/INSERT/UPDATE/DELETE: `user_id = auth.uid()`

### CRUD RPCs

- `create_referee_blocked_date(p_start_date, p_end_date, p_reason)`
- `update_referee_blocked_date(p_id, p_start_date, p_end_date, p_reason)`
- `delete_referee_blocked_date(p_id)`
- Read via direct SELECT (RLS-protected)

### Matching Integration

Add to `process_matching` referee candidate filter:

```sql
AND NOT EXISTS (
    SELECT 1 FROM public.referee_blocked_dates rbd
    WHERE rbd.user_id = rats.user_id
    AND (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date
        BETWEEN rbd.start_date AND rbd.end_date
)
```

---

## Feature 3: Pending Request Retry & Expiration

### Cron Job: `process_pending_requests`

**Schedule:** Every hour (pg_cron)

**Processing:**

1. **Retry matching** for pending requests where `task.due_date - interval '<rematch_cutoff_hours> hours' > NOW()`:
   - Call `process_matching` for each pending request
   - Exclude cancelled referees for the same task
   - Exclude blocked dates

2. **Expire** pending requests where `task.due_date - interval '<rematch_cutoff_hours> hours' <= NOW()`:
   - Set request status to `expired`
   - Refund locked points: decrement `point_wallets.locked`, add `point_histories` record with `transaction_type = 'matching_refunded'`
   - Notify tasker: `notification_matching_expired_refunded_tasker`

### Point Refund

New transaction type: `matching_refunded` in `point_transaction_type` enum.

Refund logic mirrors `lock_points` in reverse:
- `point_wallets.locked -= cost`
- Insert `point_histories` with negative amount and type `matching_refunded`

---

## Notification Templates

| Event | Recipient | Template ID |
|-------|-----------|-------------|
| Referee cancelled, new referee found | Tasker | `notification_matching_reassigned_tasker` |
| Referee cancelled, no new referee yet | Tasker | `notification_matching_cancelled_pending_tasker` |
| Re-matched assignment | New Referee | `notification_task_assigned_referee` (existing) |
| Pending request expired + refund | Tasker | `notification_matching_expired_refunded_tasker` |

Template IDs follow the `notification_{event}_{recipient}` naming convention from #248.

---

## Developer Documentation

Update `developer-docs/modules/ROOT/pages/features/task.adoc`:

- Add a "Time Constraints" section documenting the matching time constraint model, each parameter's purpose, and the human-behavioral rationale for the cutoffs
- Add `cancelled` and `expired` request statuses to the state descriptions
- Update `lifecycle.pu` to include the cancellation → re-matching flow
- Update `timing.pu` to include the matching phase time constraints (24h min, 14h rematch cutoff, 12h cancel deadline)

---

## MVP Scope

**In scope:**
1. `matching_time_config` singleton table with 3 time constraint values
2. `cancelled` status addition to `referee_request_status` enum
3. `matching_refunded` transaction type addition to `point_transaction_type` enum
4. `referee_blocked_dates` table with CRUD RPCs and RLS
5. `cancel_referee_assignment` RPC with configurable deadline
6. `process_matching` updates: exclude cancelled referees + blocked dates
7. Pending request retry cron job (hourly)
8. Pending request expiration + point refund (configurable cutoff)
9. Migrate `min_due_date_interval_hours` from `matching_config` to `matching_time_config` as `open_deadline_hours` (value 1 → 24)
10. Notification templates (4 new/reused)
11. Flutter UI: cancel button on referee task detail, blocked dates management screen
12. Developer documentation: time constraint model in `task.adoc`
13. DB unit tests

**Out of scope:**
- Tasker-initiated cancellation
- Time-of-day blocking (only full-day blocks)
- Extra availability for specific dates
