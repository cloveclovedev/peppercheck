# Notification Audit Fix Design

Issue: #257
Audit Document: PR #306

## Overview

Comprehensive fix for notification system gaps identified in the notification audit. Addresses 5 bugs (BUG-1 through BUG-5), evidence notification content issue (section 5), and unifies notification text across all 5 layers.

## Scope

### In scope

- **BUG-1/2/3**: Add missing judgement notification implementations across all layers
- **BUG-4**: Complete `notification_payout_connect_required_referee` across missing layers
- **BUG-5**: Rename `notification_payout_failed` to `notification_payout_failed_referee` and complete all layers
- **Section 5 fix**: Fix evidence notifications using task title as person name
- **Text refinement**: Unify tone and wording for all notifications

### Out of scope

- GAP-1 (evidence deadline warning) → #310
- GAP-2 (judgement deadline warning) → #311
- GAP-3 (`notification_request_accepted` as future manual accept step) → deferred

### Also in scope (added during review)

- **BUG-6**: Delete `notification_request_accepted` dead code from all client layers (Flutter resolver, ja.i18n.json, Android strings.xml, iOS Localizable.strings). No SQL trigger fires this key; it violates naming convention (missing `_tasker` suffix). If a manual accept step is needed in the future, it should be re-created as `notification_request_accepted_tasker`.

## Notification Data Flow

```
SQL trigger / Edge Function
  └→ notify_event(user_id, 'notification_{event}_{recipient}', ARRAY[task_title], {task_id: ...})
      └→ _title / _body suffix auto-appended
          └→ Edge Function (send-notification)
              └→ FCM multicast
                  ├→ Android background: strings.xml loc_key resolution
                  ├→ iOS background: Localizable.strings loc_key resolution
                  └→ Foreground: notification_text_resolver.dart → slang t.notification.*
```

## 5-Layer Checklist (per notification key)

Every notification key must exist in all 5 layers:

1. **SQL** `notify_event()` call (or Edge Function RPC call)
2. **Flutter** `notification_text_resolver.dart` switch cases
3. **Flutter** `ja.i18n.json` notification section (without `notification_` prefix)
4. **Android** `strings.xml` (en + ja) with `_title` / `_body` suffixed keys
5. **iOS** `Localizable.strings` (en + ja) with `_title` / `_body` suffixed keys

## Finalized Notification Text

### Matching Phase

| Key | Recipient | Title | Body |
|-----|-----------|-------|------|
| `notification_request_matched_tasker` | Tasker | マッチング成立！ | 「{task}」のレフリーが見つかりました！ |
| `notification_task_assigned_referee` | Referee | 新しい担当タスクが届きました！ | 「{task}」の担当レフリーに選ばれました。 |
| `notification_matching_reassigned_tasker` | Tasker | レフリーが変更されました | 「{task}」に新しいレフリーが割り当てられました。 |
| `notification_matching_cancelled_pending_tasker` | Tasker | マッチングがキャンセルされました | 「{task}」のレフリーがキャンセルしたため、新しいレフリーを探しています。 |
| `notification_matching_expired_refunded_tasker` | Tasker | レフリーが見つかりませんでした | 「{task}」のレフリーが見つかりませんでした。ポイントは返金済みです。 |

### Evidence Phase

| Key | Recipient | Title | Body |
|-----|-----------|-------|------|
| `notification_evidence_submitted_referee` | Referee | エビデンスが届きました！ | 「{task}」に新しいエビデンスが提出されました。確認してください。 |
| `notification_evidence_updated_referee` | Referee | エビデンスが更新されました | 「{task}」のエビデンスが更新されました。確認してください。 |
| `notification_evidence_resubmitted_referee` | Referee | エビデンスが再提出されました！ | 「{task}」のエビデンスが再提出されました。再度判定してください。 |
| `notification_evidence_timeout_tasker` | Tasker | エビデンスの提出期限を過ぎました | 「{task}」のエビデンス提出期限が過ぎたため、ポイントが消費されました。 |
| `notification_evidence_timeout_referee` | Referee | 報酬を獲得しました！ | 「{task}」のエビデンス提出期限切れにより、報酬を獲得しました。 |

### Judgement Phase

| Key | Recipient | Title | Body |
|-----|-----------|-------|------|
| `notification_judgement_approved_tasker` | Tasker | タスク達成おめでとう！ | 「{task}」が承認されました。お疲れさまでした！ |
| `notification_judgement_rejected_tasker` | Tasker | エビデンスが差し戻されました | 「{task}」が承認されませんでした。内容を確認してください。 |
| `notification_judgement_confirmed_referee` | Referee | 判定が確認されました！ | 「{task}」の判定結果が確認されました。ありがとうございました。 |
| `notification_auto_confirm_tasker` | Tasker | 判定が自動確認されました | 「{task}」の判定結果が期限内に確認されなかったため、自動的に確認されました。 |
| `notification_auto_confirm_referee` | Referee | 判定が確認されました！ | 「{task}」の判定結果が確認されました。ありがとうございました。 |

> **Note:** `judgement_confirmed_referee` and `auto_confirm_referee` intentionally share identical text. From the referee's perspective, the outcome is the same regardless of whether confirmation was manual or automatic.

| `notification_review_timeout_tasker` | Tasker | 期限内に判定されませんでした | 「{task}」が期限内に判定されなかったため、ポイントが返却されました。 |
| `notification_review_timeout_referee` | Referee | 判定期限を過ぎました | 「{task}」の判定期限が過ぎました。報酬は付与されません。 |

### Payout Phase

| Key | Recipient | Title | Body |
|-----|-----------|-------|------|
| `notification_payout_connect_required_referee` | Referee | 報酬の受取設定をお願いします | 報酬が発生しています。受け取るには振込先の設定を完了してください。 |
| `notification_payout_failed_referee` | Referee | 報酬振込に失敗しました | 報酬の振込に失敗しました。お手数ですが、アカウント設定をご確認ください。 |

### Fallback

| Key | Title | Body |
|-----|-------|------|
| `fallback` | お知らせ | 新しい通知があります。 |

## Changes by Bug

### BUG-1: `notification_judgement_approved_tasker`

Add to all 5 layers. SQL trigger already fires this key.

### BUG-2: `notification_judgement_rejected_tasker`

Add to all 5 layers. SQL trigger already fires this key.

### BUG-3: `notification_judgement_confirmed_referee`

Add to all 5 layers. SQL trigger `handle_judgement_confirmed()` in `on_judgement_confirmed.sql` already fires this key for manual confirmations. Note: the separate `on_judgement_confirmed_notify.sql` handles only the auto-confirm path.

### BUG-4: `notification_payout_connect_required_referee`

Add to: Flutter resolver, ja.i18n.json, iOS Localizable.strings. Already exists in SQL and Android strings.xml.

### BUG-5: `notification_payout_failed` → `notification_payout_failed_referee`

Rename in:
- Edge Function `execute-pending-payouts/index.ts` (template key in `notify_event` RPC call)
- Android `strings.xml` (en + ja) key names

Add to: Flutter resolver, ja.i18n.json, iOS Localizable.strings (with new name, `notification_payout_failed_referee`). Note: iOS has no existing `notification_payout_failed` keys (unlike Android which requires a rename), so iOS is a pure addition.

### BUG-6: `notification_request_accepted` — dead code removal

Delete from all client layers:
- Flutter `notification_text_resolver.dart` switch cases
- Flutter `ja.i18n.json` entries
- Android `strings.xml` (en + ja)
- iOS `Localizable.strings` (en + ja)

No SQL change needed (no trigger exists for this key).

### Section 5: Evidence notification body fix

Fix `notification_evidence_submitted_referee_body` and `notification_evidence_updated_referee_body` across all layers. The current text uses `{taskTitle}さん` as if it's a person name. Change to `「{taskTitle}」に〜` / `「{taskTitle}」の〜`.

### Text refinement (all notifications)

Update text across all 5 layers for all notification keys per the finalized text table above. Key changes:
- レフェリー → レフリー (unify spelling)
- Remove redundant 「タスク」prefix before bracketed task title
- Add/unify sentence-ending punctuation
- Titles: friendly/exciting tone (matching app style)
- Bodies: polite Japanese (敬体)

## English Notification Text

English text in Android `strings.xml` and iOS `Localizable.strings` must also be provided for all keys. English text follows the same tone: friendly titles, polite but concise bodies.

| Key | Title (EN) | Body (EN) |
|-----|-----------|----------|
| `notification_request_matched_tasker` | Match found! | A referee has been found for "{task}"! |
| `notification_task_assigned_referee` | New task assigned! | You've been assigned as referee for "{task}". |
| `notification_matching_reassigned_tasker` | Referee changed | A new referee has been assigned to "{task}". |
| `notification_matching_cancelled_pending_tasker` | Matching cancelled | The referee for "{task}" cancelled. Searching for a new referee. |
| `notification_matching_expired_refunded_tasker` | No referee found | No referee was found for "{task}". Your points have been refunded. |
| `notification_evidence_submitted_referee` | New evidence received! | New evidence has been submitted for "{task}". Please review it. |
| `notification_evidence_updated_referee` | Evidence updated | The evidence for "{task}" has been updated. Please review it. |
| `notification_evidence_resubmitted_referee` | Evidence resubmitted! | Evidence for "{task}" has been resubmitted. Please review again. |
| `notification_evidence_timeout_tasker` | Evidence deadline passed | The evidence submission deadline for "{task}" has passed. Points have been consumed. |
| `notification_evidence_timeout_referee` | Reward earned! | You earned a reward due to the evidence deadline expiring for "{task}". |
| `notification_judgement_approved_tasker` | Congratulations! | "{task}" has been approved. Great work! |
| `notification_judgement_rejected_tasker` | Evidence returned | "{task}" was not approved. Please review the details. |
| `notification_judgement_confirmed_referee` | Judgement confirmed! | Your judgement for "{task}" has been confirmed. Thank you! |
| `notification_auto_confirm_tasker` | Judgement auto-confirmed | The judgement for "{task}" was not confirmed in time and has been automatically confirmed. |
| `notification_auto_confirm_referee` | Judgement confirmed! | Your judgement for "{task}" has been confirmed. Thank you! |
| `notification_review_timeout_tasker` | Not judged in time | "{task}" was not judged in time. Your points have been returned. |
| `notification_review_timeout_referee` | Judgement deadline passed | The judgement deadline for "{task}" has passed. No reward will be granted. |
| `notification_payout_connect_required_referee` | Payout setup required | You have a pending reward. Please set up your payout account to receive it. |
| `notification_payout_failed_referee` | Payout failed | Your payout could not be processed. Please check your account settings. |

## Files to Modify

1. `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`
2. `peppercheck_flutter/assets/i18n/ja.i18n.json`
3. `peppercheck_flutter/android/app/src/main/res/values/strings.xml` (EN)
4. `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml` (JA)
5. `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings` (EN)
6. `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings` (JA)
7. `supabase/functions/execute-pending-payouts/index.ts` (BUG-5 rename only)

No SQL changes needed — all SQL triggers already fire the correct keys (except BUG-5 rename is at the Edge Function level, not SQL).

After modifying `ja.i18n.json`, regenerate slang: `cd peppercheck_flutter && dart run build_runner build`
