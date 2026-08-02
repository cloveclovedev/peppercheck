# Judgement Timeout (Review Timeout) Design

Issue: #72

## Overview

When a referee fails to review a task's evidence within the deadline, the system automatically times out the judgement, returns points to the tasker, and records a negative rating for the referee.

This follows the same 3-layer architecture as Evidence Timeout: Detection → Settlement → Tasker Confirmation.

## Trigger Condition

- Judgement status: `in_review` (evidence submitted, awaiting referee review)
- Current time > `task.due_date + INTERVAL '3 hours'`

The 3-hour grace period is defined as a constant in the detection SQL function.

## Layer 1: Detection (Cron)

**Function:** `detect_and_handle_review_timeouts()`

- Cron schedule: `*/5 * * * *` (every 5 minutes, separate job from evidence timeout)
- Finds all judgements where `status = 'in_review'` and `now() > task.due_date + 3h`
- Updates status to `review_timeout`
- Returns JSON with success status and count

## Layer 2: Settlement (Trigger)

**Trigger:** `on_review_timeout_settle`
**Function:** `settle_review_timeout()`

Fires when judgement status changes to `review_timeout`. Performs atomically:

1. **Point return:** `unlock_points(tasker, cost, 'matching_unlock')` — locked points returned to tasker's available balance
2. **No referee reward** — referee forfeits reward due to timeout
3. **Auto Bad rating:** Insert into `rating_histories` with `is_positive = false`, `rating_type = 'referee'`, `rater_id = tasker_id`, `comment = NULL`
4. **Close referee_request:** Direct update to `status = 'closed'` (no intermediate flag needed)
5. **Notify tasker:** `notify_event(tasker, 'notification_review_timeout_tasker', ARRAY[task_title], {task_id, judgement_id})`
6. **Notify referee:** `notify_event(referee, 'notification_review_timeout_referee', ARRAY[task_title], {task_id, judgement_id})`

### Comparison with Evidence Timeout Settlement

| Aspect | Evidence Timeout | Review Timeout |
|---|---|---|
| Tasker points | consume (deducted) | unlock (returned) |
| Referee reward | grant | none |
| Referee rating | none | auto Bad |
| Request close mechanism | via `is_evidence_timeout_confirmed` flag | direct close in trigger |

## Layer 3: Tasker Confirmation (RPC)

**Function:** `confirm_review_timeout(p_judgement_id uuid)`

- Validates caller is the tasker
- Validates status is `review_timeout`
- Sets `is_confirmed = true` (idempotent)
- Triggers `on_all_judgements_confirmed_close_task` → task closes when all judgements confirmed

No point processing here — already handled in settlement trigger.

## Notifications

| Recipient | Template Key | Title | Body |
|---|---|---|---|
| Tasker | `notification_review_timeout_tasker` | レビュー期限切れ | タスク「{taskTitle}」は期間内に評価されませんでした。ポイントが返却されました。 |
| Referee | `notification_review_timeout_referee` | レビュー期限切れ | タスク「{taskTitle}」のレビュー期限が過ぎました。 |

Platform localization required:
- Android: `strings.xml`
- iOS: `Localizable.strings`
- Flutter (Dart): `ja.i18n.json` (slang, for foreground display)

## Flutter UI (Tasker Side)

Same location and pattern as Evidence Timeout confirmation:

1. **`review_timeout` + `is_confirmed = false`:** Warning icon + "期間内に評価されませんでした。ポイントが返却されました。" + "確認する" button
2. **`review_timeout` + `is_confirmed = true`:** Checkmark + "確認済み" (read-only)

## DB Changes

No new enums or columns needed:
- `judgement_status.review_timeout` — already exists
- `point_reason.matching_unlock` — already exists
- `referee_request_status.closed` — already exists

## Future Considerations (Separate Issues)

1. **Simplify `is_evidence_timeout_confirmed`:** Evidence Timeout could also close referee_request directly on status change, removing the need for this flag
2. **Notification template key naming:** Standardize existing keys to `_tasker` / `_referee` suffix pattern
