# Task Detail Referees Section Redesign

Issue: #375
Date: 2026-04-29

## Background

The current `TaskRefereesSection` (`peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/task_referees_section.dart`) is shared between tasker and referee perspectives but is information-poor. It only shows an avatar placeholder, the matching strategy, and a status badge. With profile editing now in place, referees and taskers have meaningful usernames and avatars that can be surfaced.

The redesign also tightens layout: when a task has two referees, the section currently occupies two stacked rows. Side-by-side cards halve the vertical footprint without reducing legibility.

## Design Iteration Note (2026-04-29)

After an initial implementation that produced two role-specific sibling sections (`TaskerRefereesSection` + `MyRefereeRequestSection`), live UI review found that the referee-side section read as "cancel **the person** (tasker)" because of the avatar/username and cancel button being adjacent. The design was revised:

- The referee side no longer has a referees-style section. Instead, the tasker identity is embedded inside `TaskDetailInfoSection` as task metadata, and the withdraw-from-matching control becomes an action button at the bottom of the same section (mirroring how `DeleteTaskButton` already lives at the bottom of `TaskDetailInfoSection` for draft-state taskers).
- The tasker side keeps a dedicated `TaskerRefereesSection` but the per-referee card no longer shows strategy/status — only avatar + username — because strategy is effectively `standard` only and status is already visible in the task header.
- The cancel terminology shifts from "担当をキャンセル" to "マッチングを辞退" so the action verb targets the matching, not the person.

This document reflects the revised design.

## Goals

- Tasker viewers see referee identity (avatar + username) at a glance.
- Referee viewers see the requester (tasker) identity as task metadata, plus a clearly-labeled withdraw control that doesn't appear to target the person.
- Two-up horizontal layout on the tasker side when there are two referees; left-half-only when one.
- Withdraw control respects the server-side cancel deadline (cannot withdraw past `due_date - cancel_deadline_hours`).

## Non-Goals

- Tap-through to a public profile screen. No such screen exists yet; tracked as a follow-up issue.
- Displaying every referee request to the referee viewer. RLS already restricts referees to their own request.
- Three-or-more-referee layouts. Current product supports up to two.
- Localization beyond Japanese.
- Dynamic fetch of `matching_time_config` from the server (deferred follow-up; client hardcodes the deadline constant pointing to the server-side source of truth).

## Architecture

```
TaskDetailScreen
├── TaskDetailInfoSection                        (always)
│   ├── Title / Description / Criteria / Due date
│   ├── (refree view) tasker info row            (avatar + username)
│   └── (refree view + isObligation) obligation notice (muted)
├── if (currentUserId == task.taskerId)
│   └── TaskerRefereesSection                    (StatelessWidget)
│       └── _RefereeCard × 1 or 2                (private; avatar + username only)
├── EvidenceSubmissionSection / EvidenceTimeoutRefereeSection (existing, role-gated)
├── JudgementSection                             (existing)
└── WithdrawMatchingButton                       (renders only when can-withdraw)
```

The withdraw control deliberately lives outside any section as a small right-aligned button at the very bottom of the screen. Embedding it inside `TaskDetailInfoSection` was tested but felt too persistently prominent during the multi-day judgement workflow; an end-of-screen button stays discoverable without dominating the read.

Files:

- Edit: `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/tasker_referees_section.dart` — strip strategy/status from the card.
- Edit: `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/task_detail_info_section.dart` — append refree-side rows (tasker info, obligation notice) when the viewer is the matched referee.
- New: `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/withdraw_matching_button.dart` — content-sized destructive button, right-aligned at the bottom of the screen.
- Edit: `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart` — drop the role-based dispatch; render `TaskerRefereesSection` only when the viewer is the tasker; render `WithdrawMatchingButton` after `JudgementSection`.
- Edit: `peppercheck_flutter/lib/common_widgets/destructive_action_button.dart` — add `fullWidth` parameter (default `true`) so the existing destructive button can also be used at content size.
- Delete: `peppercheck_flutter/lib/features/task/presentation/widgets/task_detail/my_referee_request_section.dart` (interim widget from earlier iteration; no longer needed).
- New: `peppercheck_flutter/lib/features/matching/matching_constants.dart` — house `kRefereeCancelDeadlineHours`.
- Edit: `peppercheck_flutter/assets/i18n/ja.i18n.json` — rename `cancelAssignment.*` strings, add `labelTasker` and `cancelAssignment.dialogConfirm`, remove unused `sectionRefereesReferee`, `matchingStrategy.*`, `refereeStatus.*` keys.

## Component Specs

### `TaskerRefereesSection` (simplified)

- Input: `Task task`.
- Early return: `task.refereeRequests.isEmpty` → `SizedBox.shrink()`.
- Wrapped in `BaseSection(title: t.task.detail.sectionRefereesTasker, ...)`.
- Layout: `Row` with two `Expanded` halves; right half is empty `SizedBox.shrink()` when only one referee.

#### `_RefereeCard`

- Input: `RefereeRequest request`.
- Decoration: existing card style (`AppColors.backgroundWhite`, `baseCardBorderRadius`, `baseCardPaddingHorizontal/Vertical`).
- Content: avatar (or default person icon, size `AppSizes.avatarSizeMedium`) + bold username (`bodySmall`, ellipsis).
- When `request.referee` is null (still pending): person icon + "マッチング中" placeholder.
- **No** strategy/status text. **No** obligation notice. **No** cancel button.

### `TaskDetailInfoSection` (extended)

The component remains a single `BaseSection`. It now needs to know whether the viewer is the matched referee. Approach: compute the role inside the widget using `Supabase.instance.client.auth.currentUser?.id`, matching the existing pattern used by other role-aware widgets in this codebase.

When the viewer is the matched referee for this task — i.e., there is a `RefereeRequest r` in `task.refereeRequests` with `r.matchedRefereeId == currentUserId` — the section's child `Column` appends the following items below the existing fields:

1. **Tasker info row** (always, when refree view):
   - Label `t.task.detail.labelTasker` in the same muted small style as other field labels.
   - Below: a `BaseCard`-styled `Row` with avatar (`AppSizes.avatarSizeMedium`, fallback person icon) and bold username (`bodySmall`).
   - Username fallback: `'...'` when `task.tasker?.username` is null.

2. **Obligation notice** (only if `myRequest.isObligation == true`):
   - Single muted `Text` with `t.billing.obligationRefereeNotice`.
   - `style: bodySmall.copyWith(color: AppColors.textMuted)` — slightly smaller than primary content; inline annotation feel.

The withdraw button does NOT live here — see `WithdrawMatchingButton` below.

### `WithdrawMatchingButton`

- A standalone `ConsumerStatefulWidget` rendered as the last child of `TaskDetailScreen`'s `Column` (after `JudgementSection`).
- Self-gates rendering: returns `SizedBox.shrink()` when the viewer is not the matched referee or when withdrawal is no longer available.
- Visual: `DestructiveActionButton(fullWidth: false)` with no icon, wrapped in `Align(alignment: Alignment.centerRight)` — produces a small right-aligned destructive button at the bottom of the screen.
- Tap shows a `BaseDialog` confirmation. On confirm, calls `matchingRepository.cancelRefereeAssignment(myRequest.id)`, shows a snackbar, and invalidates `taskProvider(task.id)`, `activeUserTasksProvider`, `activeRefereeTasksProvider`.
- Dialog confirm button uses `t.task.detail.cancelAssignment.dialogConfirm` (the action verb), not the generic "確認".
- Withdrawal gate (`_canWithdraw`):
  - Must have `myRequest.status == 'accepted'`.
  - Must not be in an irreversible judgement state. Specifically, hides when `myRequest.judgement?.status` is one of `approved`, `review_timeout`, `evidence_timeout`, `confirmed`. Withdrawal stays available during `awaiting_evidence`, `in_review`, and `rejected` (the tasker may resubmit evidence after a rejection).
  - Must still be before the cancel deadline:
    ```
    task.dueDate == null
        || DateTime.parse(task.dueDate!).isAfter(
             DateTime.now().add(Duration(hours: kRefereeCancelDeadlineHours)),
           )
    ```
  - If `task.dueDate` is null, the deadline check is treated as passing. The server-side validation is the authoritative gate; the client value exists for UX only.

### `kRefereeCancelDeadlineHours`

- Location: `peppercheck_flutter/lib/features/matching/matching_constants.dart`
- Value: `12`
- Source of truth: server-side `matching_time_config.cancel_deadline_hours` (singleton table). The client mirrors this constant; if the server config changes, both must be updated.
- A follow-up could expose the config via an API and remove this hardcode.

### `TaskDetailScreen`

- No more role-based dispatch around the referees section.
- Render `TaskerRefereesSection(task: displayTask)` unconditionally and let it short-circuit to `SizedBox.shrink()` when irrelevant. Optionally gate at the screen level on `currentUserId == task.taskerId` to avoid rendering a referee-side leak path; the widget handles it gracefully either way. **Decision:** keep the screen-level gate so referees never even mount the widget — preserves the existing role-aware pattern in this file.

## Data Flow

- Tasker view consumes `task.refereeRequests[*].referee` (`Profile?`), already aggregated by the matching repository.
- Referee view consumes `task.tasker` (`Profile?`), aggregated via the `tasker_profile:profiles!tasker_id (*)` join already added to `getTask` and `fetchActiveUserTasks`.
- `task.refereeRequests` is filtered server-side by RLS; the referee viewer sees only their own request.

## i18n

### Keys to remove

- `task.detail.sectionRefereesReferee`
- `task.detail.matchingStrategy.standard / .premium / .direct`
- `task.detail.refereeStatus.pending / .matched / .accepted / .declined / .expired / .paymentProcessing / .closed / .cancelled`

### Keys to add

- `task.detail.labelTasker` ("依頼者")
- `task.detail.cancelAssignment.dialogConfirm` ("辞退") — used as the dialog confirm button so it reads as the action verb rather than a generic "確認"

### Keys to update (value change only, key names preserved)

| Key | Old | New |
|---|---|---|
| `task.detail.cancelAssignment.button` | "担当をキャンセル" | "マッチングを辞退" |
| `task.detail.cancelAssignment.dialogTitle` | "担当のキャンセル" | "マッチングの辞退" |
| `task.detail.cancelAssignment.dialogMessage` | "担当をキャンセルしますか？" | "マッチングを辞退しますか？" |
| `task.detail.cancelAssignment.success` | "担当をキャンセルしました" | "マッチングを辞退しました" |

`task.detail.cancelAssignment.error` keeps its generic "エラーが発生しました: $message" wording.

### Keys to keep (used by simplified TaskerRefereesSection)

- `task.detail.sectionRefereesTasker` ("レフリー")
- `task.detail.refereePending` ("マッチング中")

## Behavior Examples

| Viewer | refereeRequests | Render |
|---|---|---|
| Tasker | 1 referee, status=`pending`, referee=null | `TaskerRefereesSection` left card only: default person icon + "マッチング中" |
| Tasker | 1 referee, status=`accepted`, referee=alice | `TaskerRefereesSection` left card only: alice avatar + username |
| Tasker | 2 referees | Two cards side by side, equal width |
| Referee | self matched, status=`accepted`, isObligation=false, due_date > now+12h, judgement=`awaiting_evidence` | `TaskDetailInfoSection` shows tasker info row. `WithdrawMatchingButton` renders a small destructive button at the bottom of the screen. No `TaskerRefereesSection`. |
| Referee | self matched, isObligation=true | Same as above + obligation notice below the tasker info row. |
| Referee | self matched, status=`accepted`, due_date <= now+12h | Tasker info row visible; withdraw button hidden (deadline passed). |
| Referee | self matched, judgement=`approved` / `review_timeout` / `evidence_timeout` / `confirmed` | Tasker info row visible; withdraw button hidden (irreversible state). |
| Referee | self matched, judgement=`in_review` or `rejected` | Withdraw button still visible (referee may still need to act on resubmitted evidence). |
| Referee | self matched, status=`closed` or `payment_processing` | Tasker info row visible; withdraw button hidden. |
| Either | task has no refereeRequests | `TaskerRefereesSection` (tasker) is hidden. `TaskDetailInfoSection` does not append refree-side content (refree role check fails). `WithdrawMatchingButton` self-hides. |

## Testing

The repository has no widget-test precedent for this screen. Verification is manual on the Android emulator, plus a debug build check.

- [ ] `flutter build apk --debug -t lib/main_debug.dart` succeeds.
- [ ] Tasker view, 1 referee → left-half card only (avatar + bold username).
- [ ] Tasker view, 2 referees → two equal-width cards.
- [ ] Tasker view, `pending` request → placeholder text + default icon.
- [ ] Referee view → no `TaskerRefereesSection` rendered.
- [ ] Referee view → `TaskDetailInfoSection` contains the tasker info row at the bottom of the existing fields.
- [ ] Referee view, `isObligation=true` → obligation notice visible below the tasker row.
- [ ] Referee view, `accepted` + `due_date > now+12h` + judgement `awaiting_evidence` → withdraw button visible at the bottom of the screen, right-aligned. Tap → `BaseDialog` confirmation → withdraw succeeds, providers invalidate, snackbar shows.
- [ ] Referee view, judgement `approved` → withdraw button hidden.
- [ ] Referee view, judgement `rejected` or `in_review` → withdraw button still visible (gate allows pre-terminal states).
- [ ] Referee view, `due_date <= now+12h` → withdraw button hidden.
- [ ] Referee view, `closed` or `payment_processing` → withdraw button hidden.
- [ ] No leftover references to `MyRefereeRequestSection`, `sectionRefereesReferee`, `matchingStrategy.*`, or `refereeStatus.*`.

## Follow-ups

- New issue: tap on avatar/username (in either the tasker-side referee card or the refree-side tasker info row) to view the other party's public profile. Blocked on a "view another user's profile" screen which does not yet exist.
- New issue: fetch `matching_time_config` from the server and remove the `kRefereeCancelDeadlineHours` hardcode.

## Risks and Mitigations

- **Username overflow**: `maxLines: 1` with ellipsis on all username `Text` widgets. Layout uses `Expanded` so ellipsis triggers correctly.
- **`task.tasker` not populated**: addressed by the `tasker_profile` join in `getTask` and `fetchActiveUserTasks` (already shipped).
- **Cancel deadline drift between client and server**: server-side check in `cancelRefereeAssignment` is the authoritative gate; the client value is for UX only. If the server rejects past the deadline, the user sees the generic error snackbar.
- **Stale i18n keys after deletion**: each key removal is paired with a Flutter build verification — slang regen drops the getters, and the analyzer rejects any stale `t.task.detail.*` reference.
