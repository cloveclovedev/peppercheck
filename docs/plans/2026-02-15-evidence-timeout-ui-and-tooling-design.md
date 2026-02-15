# Evidence Timeout UI & Test Tooling Design

Date: 2026-02-15
Issue: #72

## Context

Backend for evidence timeout settlement is fully implemented (cron detection, settlement trigger, confirm RPC, task closure trigger, notifications). The remaining work is:

1. Flutter UI for tasker to confirm evidence timeout
2. Test tooling to create expired tasks for emulator testing
3. Document remaining notification work

## 1. Flutter UI: Evidence Section Timeout State

### Approach

Add a third state to `EvidenceSubmissionSection`. Currently it handles:
- **Evidence submitted** → read-only view of submitted evidence
- **No evidence, form visible** → submission form

New state:
- **Evidence timeout** → timeout notification + confirm button

### Detection Logic

The Task domain model already includes `Task → RefereeRequest → Judgement`. Judgement has `status` and `isConfirmed` fields. No additional queries needed.

```dart
// Evidence not submitted AND any judgement has status 'evidence_timeout'
bool hasEvidenceTimeout =
  task.evidence == null &&
  task.refereeRequests.any((r) => r.judgement?.status == 'evidence_timeout');

// All evidence_timeout judgements confirmed by tasker
bool isTimeoutConfirmed =
  task.refereeRequests.every(
    (r) => r.judgement?.status != 'evidence_timeout' || r.judgement!.isConfirmed
  );
```

### UI States

| Condition | Display |
|---|---|
| `evidence != null` | Existing: submitted evidence (read-only) |
| `hasEvidenceTimeout && !isTimeoutConfirmed` | Timeout alert + confirm button |
| `hasEvidenceTimeout && isTimeoutConfirmed` | Timeout confirmed (read-only) |
| Otherwise | Existing: evidence submission form |

### Timeout Display

Within `BaseSection`:
- Title: "エビデンス"
- Warning icon + text: "期限を過ぎました。ポイントが支払われました。"
- Confirm button: "確認する"
- On tap: call `confirm_evidence_timeout` RPC → invalidate taskProvider → show confirmed state
- No confirmation dialog (instant confirm)

### Files to Change

| File | Change |
|---|---|
| `evidence_submission_section.dart` | Add timeout state detection and UI |
| `evidence_controller.dart` | Add `confirmEvidenceTimeout(judgementId)` method |
| `evidence_repository.dart` | Add `confirmEvidenceTimeout(judgementId)` RPC call |
| `ja.i18n.json` | Add timeout-related strings |
| `task_detail_screen.dart` | Update `_shouldShowEvidenceSection` for timeout visibility |

## 2. Test Tooling: `supabase/snippets/create_expired_task.sql`

SQL snippet with configurable parameters:
- `v_tasker_id` and `v_referee_id` set at top of file
- Creates: task (due_date = yesterday), referee_request (accepted), judgement (awaiting_evidence)
- Runs `detect_and_handle_evidence_timeouts()` to trigger settlement
- Includes verification query to confirm results

## 3. Notification Remaining Work (Out of Scope)

To be documented in issue #72:
- Edge Function `send-notification`: add templates for `notification_evidence_timeout` and `notification_evidence_timeout_reward` (title/body text)
- Flutter FCM handler: route `notification_evidence_timeout` tap to task detail screen
- i18n: notification title/body localization
