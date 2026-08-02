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
                                               (update existing record, reopen_count++)
                                               conditions: reopen_count<1, due_date>now(), !is_confirmed
```

## RPC Design

### `submit_evidence(p_task_id, p_description, p_assets)` — Modified

Simplified to handle initial submission only. `awaiting_evidence` → `in_review`.

Changes:
- Remove `in_review` and `rejected` from accepted states
- Only accept `awaiting_evidence`

### `resubmit_evidence(p_evidence_id, p_description, p_assets_to_add, p_asset_ids_to_remove)` — New

Resubmission after rejection. `rejected` → `in_review`. Updates existing evidence in-place (same as `update_evidence` logic) + transitions judgement.

Processing order:
1. Validate (`rejected`, `reopen_count<1`, `due_date>now()`, `!is_confirmed`, tasker auth)
2. Update existing evidence record (description, add/remove assets) — evidence trigger fires but skips notification because judgement is still `rejected`
3. Update judgement (`status='in_review'`, `reopen_count++`) — judgement trigger fires, detects `rejected → in_review` with `reopen_count > 0`, sends "resubmitted" notification to referee

### `update_evidence(p_evidence_id, p_description, p_assets_to_add, p_asset_ids_to_remove)` — New

Edit evidence during `in_review`. No judgement state change.

Processing:
- Overwrite existing evidence description
- Delete specified assets, add new assets
- Referee notification fires via existing trigger (on UPDATE)

## Evidence Record Strategy

- **Edit during in_review**: Update existing record (in-place replacement). Minor fixes don't need history.
- **Resubmit after rejected**: Update existing record (in-place replacement). Both edit and resubmit use the same evidence update logic; the difference is only in judgement state transition.

## Notifications

Two triggers collaborate to avoid duplicate notifications during resubmission:

### `on_task_evidences_upserted_notify_referee` (evidence trigger)

| Condition | Action |
|---|---|
| INSERT | Send `notification_evidence_submitted` to referee |
| UPDATE + judgement is `rejected` | **Skip** (resubmission in progress — judgement trigger handles it) |
| UPDATE + judgement is `in_review` | Send `notification_evidence_updated` to referee |

### `on_judgements_status_changed` (judgement trigger)

| Condition | Action |
|---|---|
| `rejected → in_review` + `reopen_count > 0` | Send `notification_evidence_resubmitted` to referee |
| `→ approved` | Send `notification_judgement_approved` to tasker (existing) |
| `→ rejected` | Send `notification_judgement_rejected` to tasker (existing) |

This works because `resubmit_evidence` updates evidence FIRST (while judgement is still `rejected`), then updates judgement. Each trigger makes decisions based on the current state at the time it fires — fully declarative, no session variables needed.

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
- `on_task_evidences_upserted_notify_referee` — skip notification on UPDATE when judgement is `rejected`
- `on_judgements_status_changed` — add `rejected → in_review` case to send "resubmitted" notification to referee
- Flutter: evidence submission UI (add edit mode, resubmit button)
- Flutter: evidence repository (add `updateEvidence()`, `resubmitEvidence()` methods)

### Create
- `supabase/schemas/evidence/functions/resubmit_evidence.sql`
- `supabase/schemas/evidence/functions/update_evidence.sql`
- FCM notification template `notification_evidence_resubmitted`

### No Changes Needed
- `judgements` table schema (`reopen_count` column already exists)
- `judge_evidence()` — unchanged
- `confirm_judgement_and_rate_referee()` — unchanged
