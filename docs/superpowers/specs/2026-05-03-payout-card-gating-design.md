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

**`peppercheck_flutter/lib/features/payment_dashboard/presentation/widgets/payment_summary_section.dart`** — gate the payout info card on Stripe Connect setup completion.

1. Convert `_SummaryContent` from `StatelessWidget` to `ConsumerWidget` so it can read `payoutControllerProvider`.
2. Read the existing payout setup status:
   ```dart
   final isPayoutSetupComplete =
       ref.watch(payoutControllerProvider).value?.isComplete ?? false;
   ```
3. AND this into the existing visibility condition for the payout info `BaseCard`:
   ```dart
   if (isPayoutSetupComplete &&
       (summary.recentPayout != null ||
           (summary.rewards != null && summary.rewards!.balance > 0))) ...
   ```

The reward-balance + total-earned row, the trial/regular points card, and the obligations card are **not** changed — they remain visible regardless of payout setup state.

### Why frontend-only

`payoutControllerProvider` is already watched on the same Wallet screen by `PayoutSetupSection`, so reading it from `PaymentSummarySection` adds no extra fetch. Keeping the gate in the UI avoids a `get_payment_summary()` migration and keeps the SQL function single-purpose (point/reward data only, not display policy).

### Visibility matrix

| `PayoutSetupStatus` | Payout info card | Reward balance / total earned | Points card | Obligations |
|---|---|---|---|---|
| `isNotStarted` | hidden | shown | shown | shown |
| `isInProgress` | hidden | shown | shown | shown |
| `isPendingVerification` | hidden | shown | shown | shown |
| `isComplete` (and existing condition) | shown | shown | shown | shown |
| AsyncLoading / AsyncError | hidden | shown | shown | shown |

`isComplete` is defined as `chargesEnabled && payoutsEnabled` (see `peppercheck_flutter/lib/features/payout/domain/payout_setup_status.dart`). Only this state shows the payout card — the three intermediate states (`isInProgress`, `isPendingVerification`, `isNotStarted`) all hide it, since `prepare_monthly_payouts` skips them all.

### Loading and error handling

`value?.isComplete ?? false` collapses AsyncLoading and AsyncError into "hidden". This is intentional:

- **Loading**: a brief flicker on revisit ("missing → appears") for already-set-up users is acceptable; showing a stale or guessed state is worse.
- **Error**: errors in fetching Connect status are already surfaced by `PayoutSetupSection` directly above. Duplicating an error state in `PaymentSummarySection` would clutter the screen.

### Edge cases

- **Setup complete with `recentPayout.status='skipped'` in history.** The card shows "直近 ¥X (スキップ)". Intentional — we do not retroactively hide history once the user has earned the right to see their wallet activity.
- **Setup transitions from complete → not complete** (Stripe re-verification, account flagged). The card disappears while in that state. This matches reality: the next month's payout *will* be skipped if the state persists.
- **Setup just completed, reward balance is 0, no past payouts.** The existing inner condition (`recentPayout != null || balance > 0`) already keeps the card hidden. Behavior unchanged.

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
4. **`isComplete`** (`charges_enabled=true`, `payouts_enabled=true`) with a non-zero reward balance: card present with "次回振り込み予定" row.
5. **`isComplete`** with a `status='skipped'` historical row: "直近 ¥X (スキップ)" is shown alongside the next-payout row. (Intentional.)

Build verification: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart`.

### Out of scope

- Changing `next_payout_date` computation in `get_payment_summary()`.
- Changing `prepare_monthly_payouts()` skip behavior or the `notification_payout_connect_required_referee` flow.
- Renaming `peppercheck_flutter/lib/features/billing/` to `point/` (tracked separately).
- Web app parity: web does not currently render this section; no change needed.
