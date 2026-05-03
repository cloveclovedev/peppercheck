# Payout Info Card: Gate on Stripe Connect Setup Completion

**Date:** 2026-05-03

## Problem

On the Wallet screen, the **ポイント・報酬** (`PaymentSummarySection`) currently shows a payout info card with two rows:

- **直近** — most recent `reward_payouts` row (any status)
- **次回振り込み予定** — last day of the current month, computed unconditionally

This card is visible even when the user has not finished Stripe Connect onboarding (i.e. `payouts_enabled = false`). Two concrete problems result:

1. **A future payout date is shown to a user whose payouts will not happen.** The same screen has a separate **出金設定** section that says "報酬を受け取るには決済サービスStripeでの出金設定が必要です。" The mismatch — "you need to set this up" *and* "your next payout is on 5/31" — is contradictory and confusing.
2. **A skipped past payout is rendered as "直近 ¥X (スキップ)".** For a first-time user who hasn't onboarded, this looks like a failure rather than the expected outcome of an unfinished setup.

The skip behavior itself is correct: `prepare_monthly_payouts()` (`supabase/schemas/reward/functions/prepare_monthly_payouts.sql`) checks `stripe_accounts.payouts_enabled` per user and inserts a `status='skipped'` row without calling `stripe.transfers.create`. No Stripe instruction is sent. So the issue is purely a UI confusion: we show information that implies an active payout pipeline when there is none.

## Design

### Change

**`peppercheck_flutter/lib/features/payment_dashboard/presentation/widgets/payment_summary_section.dart`** — two coordinated changes:

**(a) Gate the whole payout info card on Connect setup completion.**

1. Convert `_SummaryContent` from `StatelessWidget` to `ConsumerWidget` so it can read `payoutControllerProvider`.
2. Read the existing payout setup status:
   ```dart
   final isPayoutSetupComplete =
       ref.watch(payoutControllerProvider).value?.isComplete ?? false;
   ```
3. AND this into the visibility condition for the payout info `BaseCard`.

**(b) Always hide the "直近" row when the most recent payout has `status='skipped'`.**

A skipped payout is bookkeeping for "we did nothing because the account wasn't ready". The skip event is already communicated to the user via the `notification_payout_connect_required_referee` push notification at skip time; re-surfacing it on the wallet — especially right after Connect setup completes — produces a "did my setup not work?" moment of confusion. `success` / `pending` / `failed` continue to show.

This is implemented by introducing two local booleans in `_SummaryContent.build` and threading them through the existing condition tree:

```dart
final hasRecentPayoutToShow =
    summary.recentPayout != null && summary.recentPayout!.status != 'skipped';
final hasRewardBalance =
    summary.rewards != null && summary.rewards!.balance > 0;
```

The outer guard, the inter-row spacer, and the inner "直近" `if` all key off these locals.

The reward-balance + total-earned row, the trial/regular points card, and the obligations card are **not** changed — they remain visible regardless of payout setup state.

### Why frontend-only

`payoutControllerProvider` is already watched on the same Wallet screen by `PayoutSetupSection`, so reading it from `PaymentSummarySection` adds no extra fetch. Keeping the gate in the UI avoids a `get_payment_summary()` migration and keeps the SQL function single-purpose (point/reward data only, not display policy).

### Visibility matrix

Card-level (driven by `isPayoutSetupComplete`):

| `PayoutSetupStatus` | Payout info card | Reward balance / total earned | Points card | Obligations |
|---|---|---|---|---|
| `isNotStarted` | hidden | shown | shown | shown |
| `isInProgress` | hidden | shown | shown | shown |
| `isPendingVerification` | hidden | shown | shown | shown |
| `isComplete` (and at least one inner row qualifies) | shown | shown | shown | shown |
| AsyncLoading / AsyncError | hidden | shown | shown | shown |

`isComplete` is defined as `chargesEnabled && payoutsEnabled` (see `peppercheck_flutter/lib/features/payout/domain/payout_setup_status.dart`). Only this state shows the payout card — the three intermediate states (`isInProgress`, `isPendingVerification`, `isNotStarted`) all hide it, since `prepare_monthly_payouts` skips them all.

Row-level (within the card, when `isComplete`):

| Row | Visible when |
|---|---|
| 直近 (recent payout) | `recentPayout != null` AND `recentPayout.status != 'skipped'` |
| 次回振り込み予定 (next payout date) | `rewards != null` AND `rewards.balance > 0` |

### Loading and error handling

`value?.isComplete ?? false` collapses AsyncLoading and AsyncError into "hidden". This is intentional:

- **Loading**: a brief flicker on revisit ("missing → appears") for already-set-up users is acceptable; showing a stale or guessed state is worse.
- **Error**: errors in fetching Connect status are already surfaced by `PayoutSetupSection` directly above. Duplicating an error state in `PaymentSummarySection` would clutter the screen.

### Edge cases

- **Setup just completed, most recent payout in history is `status='skipped'`.** The "直近" row stays hidden (per (b) above). The "次回振り込み予定" row shows. Without (b) the user would see "直近 ¥X (スキップ)" right after celebrating completion — the most acute confusion case observed in emulator testing.
- **Setup complete, latest payout is `skipped` but an older payout was `success`.** Backend `get_payment_summary()` returns the latest row only, so the older success is not reachable through this view. The 直近 row is hidden; the user still sees 累計受取額 and 次回振り込み予定. Acceptable: this state is rare (success → re-verification → another skip cycle) and 累計受取額 still confirms past activity.
- **Setup transitions from complete → not complete** (Stripe re-verification, account flagged). The card disappears while in that state. This matches reality: the next month's payout *will* be skipped if the state persists.
- **Setup just completed, reward balance is 0, no past payouts.** Outer guard `hasRecentPayoutToShow || hasRewardBalance` is false → card hidden. Behavior unchanged from before.
- **`status='failed'` or `status='pending'` recent payout.** Shown unchanged. Failure requires user attention; pending is informational ("transfer in transit").

### Files changed

```
peppercheck_flutter/
  lib/features/payment_dashboard/presentation/widgets/
    payment_summary_section.dart   # MODIFY: gate payout info card
```

No backend changes. No migrations. No new providers. No data model changes.

### Tests

There are no existing widget tests under `test/features/payment_dashboard/` — only a domain test for `PayoutSetupStatus` at `test/features/payout/domain/payout_setup_status_test.dart`, which is unaffected. The new gate is a pure conditional on an external provider; no new unit tests are added. Manual verification on the Android emulator covers the four `PayoutSetupStatus` states.

### Manual verification

On the Android emulator, with a test user, walk through each state:

1. **`isNotStarted`** (no `stripe_accounts` row): payout info card is absent; reward balance + total earned are still shown.
2. **`isInProgress`** (`charges_enabled=true`, `payouts_enabled=false`): card absent.
3. **`isPendingVerification`** (`pending_verification` non-empty): card absent.
4. **`isComplete`** (`charges_enabled=true`, `payouts_enabled=true`) with a non-zero reward balance and no past payouts: card present with **only** "次回振り込み予定" row.
5. **`isComplete`** with a `status='skipped'` recent row: 直近 row is **hidden**, next-payout row is shown. (Skipped suppression behavior — case (b).)
6. **`isComplete`** with a `status='success'` recent row: 直近 row is shown ("直近 ¥X (成功) — YYYY/M/D"), next-payout row is shown.

Build verification: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart`.

### Out of scope

- Changing `next_payout_date` computation in `get_payment_summary()`.
- Changing `prepare_monthly_payouts()` skip behavior or the `notification_payout_connect_required_referee` flow.
- Renaming `peppercheck_flutter/lib/features/billing/` to `point/` (tracked separately).
- Web app parity: web does not currently render this section; no change needed.
