# Reopen & Evidence Update Design

Issue: #72

## Overview

Implement a Reopen feature that allows a Tasker to resubmit evidence once after rejection, transitioning the judgement back to `in_review`. Also implement evidence editing during `in_review` so Taskers can fix minor mistakes before the Referee makes a decision.

## Requirements

- **Reopen (resubmit)**: When `rejected` + `is_confirmed=false` + `reopen_count<1` + `due_date>now()`, Tasker can resubmit evidence to transition directly to `in_review` (single step). Maximum 1 reopen.
- **Evidence update**: During `in_review`, Tasker can edit evidence description and images (no limit on edits). Referee is notified on each update.
- Same Referee reviews the resubmitted evidence.
- Once `is_confirmed=true`, Reopen is no longer possible.
- Old R2 files are not deleted immediately; a separate batch process will handle cleanup.

## State Transitions

```
awaiting_evidence ──submit_evidence()──→ in_review ──judge_evidence()──→ approved
                                            │    │                       rejected
                                            │    │                         │
                                            │    ←──update_evidence()──    │
                                            │       (update existing)      │
                                            │                             │
                                            ←──resubmit_evidence()────────┘
                                               (create new record, reopen_count++)
                                               conditions: reopen_count<1, due_date>now(), !is_confirmed
```

## RPC Design

### `submit_evidence(p_task_id, p_description, p_assets)` — Modified

Simplified to handle initial submission only. `awaiting_evidence` → `in_review`.

Changes:
- Remove `in_review` and `rejected` from accepted states
- Only accept `awaiting_evidence`

### `resubmit_evidence(p_task_id, p_description, p_assets)` — New

Resubmission after rejection. `rejected` → `in_review`.

Processing order:
1. Validate (`rejected`, `reopen_count<1`, `due_date>now()`, `!is_confirmed`, tasker auth)
2. Update judgement (`status='in_review'`, `reopen_count++`) — update first so trigger can read it
3. Create new evidence record + assets
4. Trigger fires → checks `reopen_count` to send "resubmitted" notification

### `update_evidence(p_evidence_id, p_description, p_assets_to_add, p_asset_ids_to_remove)` — New

Edit evidence during `in_review`. No judgement state change.

Processing:
- Overwrite existing evidence description
- Delete specified assets, add new assets
- Referee notification fires via existing trigger (on UPDATE)

## Evidence Record Strategy

- **Edit during in_review**: Update existing record (in-place replacement). Minor fixes don't need history.
- **Resubmit after rejected**: Create new record. The rejected evidence is preserved as a snapshot, providing context for the Referee's rejection comment.

## Notifications

Modify existing trigger `on_task_evidences_upserted_notify_referee`:

| Condition | Notification Key | Message |
|---|---|---|
| INSERT + `reopen_count = 0` | `notification_evidence_submitted` | Evidence has been submitted |
| INSERT + `reopen_count > 0` | `notification_evidence_resubmitted` | Evidence has been resubmitted. Please review again. |
| UPDATE | `notification_evidence_updated` | Evidence has been updated |

## Flutter UI

### Tasker Experience

- **in_review state**: Display existing evidence (read-only) + "Edit" button → edit mode (modify description, add/remove images) → `update_evidence()`
- **rejected + canReopen**: Display rejected evidence + Referee comment + "Resubmit Evidence" button → edit mode pre-filled with previous evidence → `resubmit_evidence()`
- **rejected + canReopen=false**: Display rejected evidence + Referee comment (read-only) + "Confirm" button only (accept result)

### `canReopen` Calculation

Computed on Flutter side from existing fields. Backend RPC performs full verification independently.

```dart
canReopen = judgement.status == 'rejected'
         && judgement.reopenCount < 1
         && judgement.isConfirmed == false
         && task.dueDate.isAfter(DateTime.now())
```

Rationale: The `due_date > now()` condition is time-dependent and cannot be maintained as a stored column without a cron job. Since the backend RPC validates all conditions regardless, client-side computation is sufficient for UI display purposes.

## Changes Summary

### Delete
- `supabase/schemas/judgement/functions/reopen_judgement.sql` + config.toml reference

### Modify
- `submit_evidence()` — simplify to `awaiting_evidence` only
- `on_task_evidences_upserted_notify_referee` — branch on `reopen_count` for INSERT notifications
- Flutter: evidence submission UI (add edit mode, resubmit button)
- Flutter: judgement repository (add `updateEvidence()`, `resubmitEvidence()` methods)

### Create
- `supabase/schemas/evidence/functions/resubmit_evidence.sql`
- `supabase/schemas/evidence/functions/update_evidence.sql`
- FCM notification template `notification_evidence_resubmitted`

### No Changes Needed
- `judgements` table schema (`reopen_count` column already exists)
- `judge_evidence()` — unchanged
- `confirm_judgement_and_rate_referee()` — unchanged
