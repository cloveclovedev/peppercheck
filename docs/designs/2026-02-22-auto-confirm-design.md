# Auto Confirm Design

Issue: #72

## Overview

When a tasker fails to confirm a judgement within a grace period after the due date, the system automatically confirms the judgement. This prevents tasks from hanging indefinitely and ensures referees receive their rewards in a timely manner.

## Trigger Condition

- Judgement `is_confirmed = false`
- Current time > `task.due_date + INTERVAL '3 days'`
- Judgement status is one of: `approved`, `rejected`, `review_timeout`, `evidence_timeout`

The 3-day grace period is hardcoded in the detection SQL function. Adjustable via migration if tuning is needed.

## Affected States

| Status | Settlement needed? | Rating | Notes |
|---|---|---|---|
| `approved` | Yes: consume_points + grant_reward | Auto-positive | Referee did their job |
| `rejected` | Yes: consume_points + grant_reward | Auto-positive | Referee did their job |
| `review_timeout` | No (already settled) | No (already auto-negative) | Only is_confirmed needed |
| `evidence_timeout` | No (already settled) | No | Only is_confirmed needed |

## Architecture: 3 Layers

### Layer 1: Detection + Processing (Cron)

**Function:** `detect_auto_confirms()`

Cron schedule: `0 * * * *` (every hour). Auto-confirm has a 3-day grace period, so hourly granularity is sufficient.

The function finds all judgements eligible for auto-confirm, then processes them:

1. **For approved/rejected:**
   - `consume_points(tasker, cost, 'matching_settled')`
   - `grant_reward(referee, cost, 'review_completed')`
   - Insert rating: `is_positive = true`, `rating_type = 'referee'`, `rater_id = tasker_id`, `comment = NULL`
   - Update: `is_auto_confirmed = true`, `is_confirmed = true`

2. **For review_timeout/evidence_timeout:**
   - Update: `is_auto_confirmed = true`, `is_confirmed = true`

Setting `is_confirmed = true` triggers the existing chain:
- `on_judgement_confirmed_close_request` → closes referee request
- `on_all_judgements_confirmed_close_task` → closes task if all judgements confirmed

### Layer 2: Notification (Trigger)

**Trigger:** `on_judgement_confirmed_notify`
**Fires when:** `is_confirmed` changes from `false` to `true`

Inside the trigger function:
- If `is_auto_confirmed = true`: send auto-confirm notifications to both tasker and referee
- Else: (future) send manual confirm notification to referee

This design keeps all confirmation notification logic in one place and avoids duplication when manual confirm notifications are added later.

### Layer 3: No RPC Needed

Auto-confirm is fully system-driven. No tasker action required.

## DB Changes

### New column on `judgements`

```sql
is_auto_confirmed boolean DEFAULT false
```

No new enums needed.

## Notifications

| Recipient | Template Key | Title | Body |
|---|---|---|---|
| Tasker | `notification_auto_confirm_tasker` | 自動確認 | タスク「{taskTitle}」の評価が自動的に確認されました。 |
| Referee | `notification_auto_confirm_referee` | 評価確認 | タスク「{taskTitle}」の評価が確認されました。 |

Platform localization required:
- Android: `strings.xml`
- iOS: `Localizable.strings`
- Flutter (Dart): `ja.i18n.json` (slang, for foreground display)

## File Structure

```
supabase/schemas/judgement/
├── functions/
│   └── detect_auto_confirms.sql                # New: detection + settlement
├── triggers/
│   └── on_judgement_confirmed_notify.sql        # New: unified confirm notification
└── cron/
    └── cron_detect_auto_confirm.sql             # New: cron schedule
```

## Trigger Chain Summary

```
Auto-confirm flow (approved/rejected):
  cron → detect_auto_confirms()
    → consume_points(tasker)
    → grant_reward(referee)
    → insert rating (auto-positive)
    → is_auto_confirmed = true, is_confirmed = true
      → on_judgement_confirmed_notify (NEW: auto-confirm notification)
      → on_judgement_confirmed_close_request (request close)
      → on_all_judgements_confirmed_close_task (task close)

Auto-confirm flow (review_timeout/evidence_timeout):
  cron → detect_auto_confirms()
    → is_auto_confirmed = true, is_confirmed = true
      → on_judgement_confirmed_notify (NEW: auto-confirm notification)
      → on_judgement_confirmed_close_request (request close)
      → on_all_judgements_confirmed_close_task (task close)
```

## Edge Cases

1. **review_timeout: request already closed.** The review timeout settlement trigger directly closes the request. When auto-confirm sets `is_confirmed = true`, the `on_judgement_confirmed_close_request` trigger fires again but the request is already closed — the UPDATE is idempotent (sets `closed` to `closed`).

2. **evidence_timeout: request already closed.** Similar to above. The `is_evidence_timeout_confirmed = true` (set during evidence timeout settlement) already closed the request. The `is_confirmed = true` update triggers the same close trigger, which is idempotent.

3. **Concurrent manual confirm.** If the tasker confirms manually just as the cron runs, the `is_confirmed = true` check ensures idempotency — the cron skips already-confirmed judgements.

4. **Multiple judgements per task.** Each judgement is auto-confirmed independently. The task closes only when all are confirmed.

## Flutter UI

No Flutter changes required for auto-confirm itself. The existing UI already handles the `is_confirmed = true` state. After auto-confirm, the task moves to closed and disappears from active lists.

## Existing Manual Confirm Referee Notification (Out of Scope)

Currently, when a tasker manually confirms via `confirm_judgement_and_rate_referee()`, the referee receives no notification. The new `on_judgement_confirmed_notify` trigger provides the infrastructure to add this in the future (the `else` branch for `is_auto_confirmed = false`). This is out of scope for this PR.
