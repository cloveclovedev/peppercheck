# Task Card Detailed Status Display

**Issue**: #353
**Date**: 2026-04-19

## Problem

Home screen task cards display incorrect/stale status labels. `Task.detailedStatus` returns the raw `task.status` (`draft`/`open`/`closed`), but the UI expects granular statuses derived from `referee_request.status` and `judgement.status`.

## Decision Log

- **Logic location**: `Task.getDetailedStatuses(String currentUserId)` method on the Freezed model. Domain logic stays in the model layer; the UI only handles display.
- **Aggregation strategy**: Per-referee display. When a task has 2 referee requests in the judgement phase, both statuses are shown side by side separated by `|`. Task-level statuses (matching phase, evidence timeout) show as a single label.
- **Filtering**: `declined` and `cancelled` referee requests are excluded from status computation because re-matching creates a new `pending` request row.
- **Tasker vs. referee view**: Determined by `currentUserId == task.taskerId`. Tasker sees aggregated state of all active requests. Referee sees only their own request's state.
- **Removed statuses**: `self_completed` and `done` from the existing UI are removed — they have no corresponding DB enum values.

## State Derivation

### Active request filtering

Exclude requests with status `declined` or `cancelled`. All logic below operates on the remaining "active" requests.

### Tasker view (`currentUserId == taskerId`)

Evaluated top-to-bottom, first match wins:

| Priority | Condition | Return value |
|---|---|---|
| 1 | `task.status == 'draft'` | `['draft']` |
| 2 | All active requests are `expired` | `['matching_failed']` |
| 3 | Any active request is `pending` or `matched` | `['matching']` |
| 4 | All active requests are `accepted` AND all judgements are `awaiting_evidence` | `['matching_complete']` |
| 5 | Any judgement is `evidence_timeout` | `['evidence_timeout']` |
| 6 | Judgement phase (`in_review` / `approved` / `rejected` / `review_timeout`) | Per-referee status list (e.g. `['in_review', 'approved']`) |
| 7 | Any request is `payment_processing` | Per-referee status list |
| 8 | All active requests are `closed` | `['closed']` |

### Referee view (`currentUserId != taskerId`)

Find the request where `matchedRefereeId == currentUserId` and return its status:

| Condition | Return value |
|---|---|
| Judgement `awaiting_evidence` | `['awaiting_evidence']` |
| Judgement `in_review` | `['in_review']` |
| Judgement `approved` | `['approved']` |
| Judgement `rejected` | `['rejected']` |
| Judgement `evidence_timeout` | `['evidence_timeout']` |
| Judgement `review_timeout` | `['review_timeout']` |
| Request `payment_processing` | `['payment_processing']` |
| Request `closed` | `['closed']` |

## Display

### TaskCard changes

- `TaskCard` becomes a `ConsumerWidget` to access `currentUserProvider` for the user ID.
- `getDetailedStatuses(currentUserId)` returns a `List<String>` of status keys.
- 1 status: single text label (current layout).
- 2 statuses: displayed side by side with `|` separator.

### Status labels and colors

| Key | Tasker label | Referee label | Color |
|---|---|---|---|
| `draft` | 下書き | — | `textMuted` |
| `matching` | マッチング中 | — | `accentYellow` |
| `matching_complete` | マッチング完了 | — | `accentGreenLight` |
| `matching_failed` | マッチング失敗 | — | `accentRed` |
| `awaiting_evidence` | — | エビデンス提出前 | `accentYellow` |
| `evidence_timeout` | エビデンス提出期限切れ | エビデンス提出期限切れ | `textSecondary` |
| `in_review` | 判定中 | 判定中 | `accentBlueLight` |
| `approved` | 承認 | 承認 | `accentGreenLight` |
| `rejected` | 却下 | 却下 | `accentBlue` |
| `review_timeout` | 判定期限切れ | 判定期限切れ | `textSecondary` |
| `payment_processing` | 支払い処理中 | 支払い処理中 | `accentYellow` |
| `closed` | 完了 | 完了 | `accentGreen` |

### i18n (`ja.i18n.json`)

Replace `task.status` keys:

```json
"status": {
  "draft": "下書き",
  "matching": "マッチング中",
  "matchingComplete": "マッチング完了",
  "matchingFailed": "マッチング失敗",
  "awaitingEvidence": "エビデンス提出前",
  "evidenceTimeout": "エビデンス提出期限切れ",
  "inReview": "判定中",
  "approved": "承認",
  "rejected": "却下",
  "reviewTimeout": "判定期限切れ",
  "paymentProcessing": "支払い処理中",
  "closed": "完了"
}
```

## Changes

### 1. `task.dart`

- Remove `detailedStatus` getter.
- Add `getDetailedStatuses(String currentUserId)` method returning `List<String>`.
- Implement active request filtering and tasker/referee view logic as specified above.

### 2. `task_card.dart`

- Change from `StatelessWidget` to `ConsumerWidget`.
- Get `currentUserId` from `currentUserProvider`.
- Call `task.getDetailedStatuses(currentUserId)` instead of `task.detailedStatus`.
- Update `_getStatusStyle` to use new status keys and support `isMyTask`-dependent labels.
- Handle list of statuses: single display or `|`-separated side-by-side display.

### 3. `ja.i18n.json`

- Replace `task.status` section with new keys as specified above.

## Not Changed

- **DB schema**: No migration. All data is already available in `referee_requests` and `judgements`.
- **Home screen / controllers**: No changes. `activeUserTasksProvider` and `activeRefereeTasks` already fetch tasks with nested `refereeRequests` and `judgements`.
- **Task detail screen**: Out of scope. This issue focuses on home screen task cards only.
