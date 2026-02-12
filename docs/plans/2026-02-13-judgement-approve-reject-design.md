# Judgement Approve/Reject Backend Design

**Related Issue:** #72 (Epic: Flutter Android) - MVP Features > Judgement: Implement approve/reject functionality

**Goal:** Enable referees to approve or reject submitted evidence via a Supabase RPC, with automatic tasker notification on status change.

**Scope:** Backend only (Supabase schema). No frontend changes. No schema migrations needed.

---

## 1. RPC Function: `judge_evidence`

**File:** `supabase/schemas/judgement/functions/judge_evidence.sql`

**Signature:**

```sql
judge_evidence(
  p_judgement_id uuid,
  p_status       judgement_status,  -- 'approved' or 'rejected' only
  p_comment      text               -- required, non-empty
) RETURNS void
```

**Validation:**

1. `p_status` must be `approved` or `rejected` (raise exception otherwise)
2. `p_comment` must be non-empty after trimming
3. Caller must be the matched referee for this judgement (`task_referee_requests.matched_referee_id = auth.uid()`)
4. Judgement current status must be `in_review`

**Action:**

- Update `judgements.status` and `judgements.comment`
- Notification is NOT sent from this function (delegated to trigger)

**Properties:**

- `SECURITY DEFINER` (consistent with existing RPC pattern)
- `SET search_path = ''`

---

## 2. Notification Trigger: `on_judgements_status_changed`

**File:** `supabase/schemas/judgement/triggers/on_judgements_status_changed.sql`

**Trigger Definition:**

- Table: `judgements`
- Event: `AFTER UPDATE`
- Condition: `OLD.status IS DISTINCT FROM NEW.status`

**Trigger Function Logic:**

1. Early return if `OLD.status = NEW.status`
2. Join `judgements.id` -> `task_referee_requests` -> `tasks` to resolve `tasker_id`
3. `CASE NEW.status`:
   - `approved` -> `notify_event(tasker_id, 'notification_judgement_approved', ...)`
   - `rejected` -> `notify_event(tasker_id, 'notification_judgement_rejected', ...)`
   - Other statuses: no-op (future extension point)
4. Notification failure does not rollback the transaction (same pattern as `notify_referee` on evidence upsert)

**Notification Template Args:**

- `task_id` (for deep-linking)
- `judgement_id`

---

## 3. Files

| Action | File |
|--------|------|
| Create | `supabase/schemas/judgement/functions/judge_evidence.sql` |
| Create | `supabase/schemas/judgement/triggers/on_judgements_status_changed.sql` |

No existing files need modification. The `judgement_status` enum already includes `approved` and `rejected`. The `judgements` table already has `status` and `comment` columns.

---

## 4. Out of Scope

- Confirm functionality (`confirm_judgement_and_rate_referee` refactor)
- Reopen functionality (already exists)
- Timeout detection
- Frontend implementation
- Point consumption / billing triggers
