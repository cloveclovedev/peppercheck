# Task Detail Referees Section Redesign

Issue: #375
Date: 2026-04-29

## Background

The current `TaskRefereesSection` (`peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/task_referees_section.dart`) is shared between tasker and referee perspectives but is information-poor. It only shows an avatar placeholder, the matching strategy, and a status badge. With profile editing now in place, referees and taskers have meaningful usernames and avatars that can be surfaced.

The redesign also tightens layout: when a task has two referees, the section currently occupies two stacked rows. Side-by-side cards halve the vertical footprint without reducing legibility.

## Goals

- Make the section meaningful for both tasker and referee viewers.
- Tasker view: show referee identity (avatar + username) at a glance.
- Referee view: show requester (tasker) identity and keep the cancel-assignment control.
- Two-up horizontal layout on the tasker side when there are two referees; left-half-only when one.

## Non-Goals

- Tap-through to a public profile screen. No such screen exists yet; tracked as a follow-up issue.
- Displaying every referee request to the referee viewer. RLS already restricts referees to their own request.
- Three-or-more-referee layouts. Current product supports up to two.
- Localization beyond Japanese. Other locales follow existing project pattern.

## Architecture

The existing single shared widget is replaced by two role-specific sibling sections, selected at the screen level. This matches the existing pattern in `task_detail_screen.dart`, which already gates `EvidenceSubmissionSection` and `EvidenceTimeoutRefereeSection` by viewer role.

```
TaskDetailScreen
├── if (currentUserId == task.taskerId)
│   └── TaskerRefereesSection      (NEW, StatelessWidget)
│       └── _RefereeCard × 1 or 2  (private)
├── else
│   └── MyRefereeRequestSection    (NEW, ConsumerStatefulWidget)
│       └── _CancelButton          (private)
└── (TaskRefereesSection is deleted)
```

Files:

- Delete: `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/task_referees_section.dart`
- New: `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/tasker_referees_section.dart`
- New: `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/my_referee_request_section.dart`
- Edit: `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart` (role-based dispatch)
- Edit: `peppercheck_flutter/assets/i18n/ja.i18n.json` (new keys; remove `task.detail.sectionRequests`)

## Component Specs

### `TaskerRefereesSection`

- Input: `Task task`.
- Early return: `task.refereeRequests.isEmpty` → `SizedBox.shrink()`.
- Wrapped in `BaseSection(title: t.task.detail.sectionRefereesTasker, ...)`.
- Layout:

  ```
  Row(
    children: [
      Expanded(child: _RefereeCard(request: requests[0])),
      SizedBox(width: AppSizes.baseCardGap),
      Expanded(
        child: requests.length > 1
            ? _RefereeCard(request: requests[1])
            : const SizedBox.shrink(),
      ),
    ],
  )
  ```

  With one referee, the right `Expanded` carries an empty `SizedBox.shrink()` so the card occupies exactly the left half. With two referees, both halves are filled evenly.

### `_RefereeCard` (tasker side)

- Input: `RefereeRequest request`.
- Decoration: matches existing card (`AppColors.backgroundWhite`, `AppSizes.baseCardBorderRadius`, `baseCardPaddingHorizontal/Vertical`).
- Content:

  ```
  Row(
    children: [
      avatar,
      SizedBox(width: AppSizes.baseCardIconGap),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(username, bold, maxLines: 1, ellipsis),
            Text('${strategyLabel} (${statusLabel})', muted, maxLines: 1, ellipsis),
          ],
        ),
      ),
    ],
  )
  ```

- `avatar`: `CircleAvatar` using `request.referee?.avatarUrl`. When null, fall back to `Icon(Icons.person, color: AppColors.textSecondary, size: AppSizes.baseCardIconSize)`.
- `username`: `request.referee?.username`. When null (referee not yet matched, e.g. `pending`), show `t.task.detail.refereePending`.
- `strategyLabel` and `statusLabel`: localized via the new keys (see i18n section below).

### `MyRefereeRequestSection`

- Input: `Task task`.
- `ConsumerStatefulWidget` because it carries cancellation state (`_isCancelling`).
- Resolves the current user's request: `task.refereeRequests.firstWhereOrNull((r) => r.matchedRefereeId == currentUserId)`. If null, render `SizedBox.shrink()` defensively.
- Wrapped in `BaseSection(title: t.task.detail.sectionRefereesReferee, ...)`.
- Single full-width card with content:

  ```
  Row(
    children: [
      avatar (task.tasker.avatarUrl, fallback Icon(Icons.person)),
      SizedBox(width: AppSizes.baseCardIconGap),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.tasker?.username ?? '...', bold, maxLines: 1, ellipsis),
            Text('${strategyLabel} (${statusLabel})', muted, maxLines: 1, ellipsis),
            if (myRequest.isObligation)
              Text(
                t.billing.obligationRefereeNotice,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
          ],
        ),
      ),
      if (myRequest.status == 'accepted') _CancelButton(...),
    ],
  )
  ```

- The obligation notice color changes from yellow accent to `AppColors.textMuted`.
- Cancel logic (`_onCancelTapped` confirmation dialog, `matchingRepository.cancelRefereeAssignment`, `ref.invalidate(taskProvider/activeUserTasksProvider/activeRefereeTasksProvider)`, snackbar feedback) is moved verbatim from the existing widget.
- `_CancelButton` widget is moved verbatim into this file as a private widget.

## Data Flow

- Tasker view consumes `task.refereeRequests[*].referee` (`Profile?`), already aggregated by the matching repository.
- Referee view consumes `task.tasker` (`Profile?`), already aggregated via the `tasker_profile:profiles!tasker_id(...)` join in the task repository (Task model line 33: `@JsonKey(name: 'tasker_profile') Profile? tasker`).
- No repository or schema changes are required. The implementation plan must verify that the task repository's SELECT clause indeed populates `tasker_profile`; if it does not, that is a small repository-side change.

## i18n

### Keys to remove

- `task.detail.sectionRequests`

### Keys to add

```json
"task": {
  "detail": {
    "sectionRefereesTasker": "レフリー",
    "sectionRefereesReferee": "リクエスト元",
    "refereePending": "マッチング中",
    "matchingStrategy": {
      "standard": "スタンダード",
      "premium": "プレミアム",
      "direct": "ダイレクト"
    },
    "refereeStatus": {
      "pending": "マッチング中",
      "matched": "マッチング完了",
      "accepted": "受諾",
      "declined": "拒否",
      "expired": "期限切れ",
      "paymentProcessing": "決済処理中",
      "closed": "完了",
      "cancelled": "キャンセル"
    }
  }
}
```

Lookups happen via small helper methods on the new sections, e.g.:

```dart
String _strategyLabel(String value) {
  switch (value) {
    case 'standard': return t.task.detail.matchingStrategy.standard;
    case 'premium':  return t.task.detail.matchingStrategy.premium;
    case 'direct':   return t.task.detail.matchingStrategy.direct;
    default:         return value; // graceful fallback
  }
}
```

A symmetric helper exists for status. Unknown values fall back to the raw string so a new enum value never crashes the UI.

## Behavior Examples

| Viewer | refereeRequests | Render |
|---|---|---|
| Tasker | 1 referee, status=`pending`, referee=null | Left card only: default person icon + "マッチング中" / "スタンダード（マッチング中）" |
| Tasker | 1 referee, status=`accepted`, referee=alice | Left card only: alice avatar + username / "スタンダード（受諾）" |
| Tasker | 2 referees | Two cards side by side, equal width |
| Referee (matched) | self matched, status=`accepted`, isObligation=false | Full-width card: tasker avatar + username / "スタンダード（受諾）" + cancel button |
| Referee (matched) | self matched, status=`accepted`, isObligation=true | Same as above + muted notice "お試し義務によるレフリーです。リワードポイントは付与されません。" |
| Referee (matched) | self matched, status=`closed` | Full-width card with no cancel button |
| Either | refereeRequests empty | Section hidden |

## Testing

The repository has no widget-test precedent for the task detail screen. Verification is manual on the Android emulator, plus a debug build check.

- [ ] `flutter build apk --debug -t lib/main_debug.dart` succeeds.
- [ ] Tasker view, 1 referee → left half card only, right side empty.
- [ ] Tasker view, 2 referees → two equal-width cards.
- [ ] Tasker view, `pending` request → "マッチング中" placeholder + default icon.
- [ ] Tasker view, `accepted` referee with avatar/username set → identity displayed.
- [ ] Tasker view, status/strategy strings render localized.
- [ ] Referee view → single full-width card showing tasker avatar/username.
- [ ] Referee view, `accepted` → cancel button visible; confirmation dialog → cancellation succeeds; providers invalidated.
- [ ] Referee view, `isObligation=true` → muted obligation notice visible.
- [ ] Referee view, `closed` → no cancel button.
- [ ] Section hidden when there are no referee requests.

## Follow-ups

- New issue: tap on avatar/username in either section to view the other party's public profile. Blocked on a "view another user's profile" screen, which does not yet exist.

## Risks and Mitigations

- **`task.tasker` not populated by the repository**: caught by manual emulator verification. If unpopulated, add the join in the implementation plan.
- **Username overflow**: cards use `maxLines: 1` with ellipsis. Two-up cards live inside `Expanded`, so each card has bounded width and ellipsis triggers correctly.
- **Unknown enum values from a future migration**: `_strategyLabel` and `_statusLabel` fall back to the raw value rather than crashing.
