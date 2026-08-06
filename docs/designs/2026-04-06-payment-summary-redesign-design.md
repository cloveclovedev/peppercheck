# Payment Summary Redesign

## Background

The current `RewardSummarySection` in the Flutter payment dashboard was created before the subscription system existed. It calls a `payout-summary` edge function that was never implemented, so the section does not work.

The goal is to replace it with a unified **PaymentSummarySection** that shows the user's complete financial picture: tasker points, trial points, reward balance with currency conversion, payout history, and total lifetime earnings.

## Design

### 1. Postgres Function: `get_payment_summary()`

A single RPC call returning all summary data as JSONB. Uses `auth.uid()` to scope to the authenticated user.

#### Return Structure

```jsonc
{
  // Tasker points (point_wallets)
  "points": {
    "balance": 5,       // total points
    "locked": 1,        // locked for pending matches
    "available": 4      // balance - locked
  },
  // Trial points (trial_point_wallets) — null if not active or not exists
  "trial_points": {
    "balance": 2,
    "locked": 0,
    "available": 2
  },
  // Referee obligations — independent of trial_points (survives subscription)
  "obligations_remaining": 1,
  // Referee rewards (reward_wallets + reward_exchange_rates) — null if no wallet
  "rewards": {
    "balance": 8,
    "currency_code": "JPY",
    "currency_exponent": 0,
    "amount_minor": 400,     // balance × rate_per_point
    "rate_per_point": 50
  },
  // Most recent payout (reward_payouts latest record) — null if none
  "recent_payout": {
    "amount_minor": 1500,
    "currency_code": "JPY",
    "status": "success",     // pending | success | failed | skipped
    "batch_date": "2026-03-31"
  },
  // Lifetime earnings (SUM of reward_payouts where status='success')
  "total_earned_minor": 5000,
  "total_earned_currency": "JPY",
  // Next payout date (last day of current month)
  "next_payout_date": "2026-04-30"
}
```

#### Implementation Notes

- Uses `LEFT JOIN` / `COALESCE` so missing rows produce null fields, never errors.
- `rewards` uses the `active=true` row from `reward_exchange_rates`. Multi-currency support: the function currently defaults to the single active rate. When multiple currencies are supported, the function will accept a currency parameter or look up the user's preferred currency.
- `next_payout_date` calculated as `(date_trunc('month', now()) + interval '1 month - 1 day')::date`.
- `obligations_remaining` counts `referee_obligations` with `status='pending'` for the user, independent of `trial_point_wallets` state. This is important because obligations persist after subscription starts and trial points are deactivated.
- `total_earned_minor` and `total_earned_currency` aggregate only `status='success'` payouts.

### 2. Flutter Domain Model

New freezed model in `features/payment_dashboard/domain/payment_summary.dart`:

```dart
@freezed
class PaymentSummary {
  PointSummary points;
  TrialPointSummary? trialPoints;
  int obligationsRemaining;
  RewardSummary? rewards;
  RecentPayout? recentPayout;
  int totalEarnedMinor;
  String? totalEarnedCurrency;
  String nextPayoutDate;
}
```

Sub-models (`PointSummary`, `TrialPointSummary`, `RewardSummary`, `RecentPayout`) are freezed classes with `fromJson` mapping directly to the Postgres function's JSON structure.

### 3. Flutter Data Layer

**New:** `features/payment_dashboard/data/payment_summary_repository.dart`

```dart
class PaymentSummaryRepository {
  Future<PaymentSummary> fetchSummary() async {
    final data = await _supabase.rpc('get_payment_summary');
    return PaymentSummary.fromJson(data);
  }
}
```

No edge function involved. Direct RPC call to the Postgres function.

### 4. Flutter Controller

**New:** `features/payment_dashboard/presentation/payment_summary_controller.dart`

Riverpod `AsyncNotifier` that calls `PaymentSummaryRepository.fetchSummary()` on build. Replaces `RewardSummaryController`.

### 5. UI: PaymentSummarySection

Unified widget replacing `RewardSummarySection` and `TrialPointWalletSection`. Uses the existing design language from `_SummaryItem` — bordered rounded containers (`BoxDecoration` with `AppColors.border`, `AppColors.backgroundLight`, `BorderRadius.circular(8)`) to visually separate each data group within the section.

#### Layout

```
┌─ BaseSection (title: "Summary") ───────────────────────┐
│                                                         │
│  ┌─ Points card ──────────────────────────────────────┐ │
│  │  🟢 Available: 4 pt                                │ │
│  │  🔒 Locked: 1 pt          ← only if locked > 0    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  ┌─ Trial Points card ────────────────────────────────┐ │
│  │  ⭐ Trial points: 2 pt    ← only if trialPoints    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  ┌─ Obligations card ─────────────────────────────────┐ │
│  │  📋 Pending: 1            ← only if > 0            │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  ┌─ Reward balance ──┐  ┌─ Total earned ─────────────┐ │
│  │  8 pt (¥400)      │  │  ¥5,000                    │ │
│  └───────────────────┘  └────────────────────────────┘ │
│           ← only if rewards != null                     │
│                                                         │
│  ┌─ Payout info card ─────────────────────────────────┐ │
│  │  Recent: ¥1,500 (success) — 2026/03/31             │ │
│  │  Next: 2026/04/30   ← only if rewards.balance > 0  │ │
│  └────────────────────────────────────────────────────┘ │
│           ← Recent row only if recentPayout != null     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Each card uses the existing `_SummaryItem` visual pattern:
- `Container` with `BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border))`
- Consistent padding with `AppSizes.spacingMedium` / `AppSizes.spacingSmall`
- Color-coded indicator dots for status (green for available, orange for locked, etc.)
- `SizedBox` for spacing between cards

#### Visibility Rules

| Element | Condition |
|---------|-----------|
| Locked points row | `points.locked > 0` |
| Trial points card | `trialPoints != null` |
| Obligations card | `obligationsRemaining > 0` |
| Rewards cards (row) | `rewards != null` |
| Recent payout row | `recentPayout != null` |
| Next payout date | `rewards != null && rewards.balance > 0` |

#### Currency Formatting

Uses existing `Currency` model + `NumberFormat.simpleCurrency`. Minor-to-major conversion via `exponent` from the Postgres response.

### 6. Payment Dashboard Screen Changes

```dart
// New order:
PaymentSummarySection(),     // unified summary (new)
SubscriptionSection(),       // existing
PayoutSetupSection(),        // existing
```

`PayoutSetupSection` (Stripe Connect setup) remains as a separate section — it is a distinct concern.

### 7. Error Handling

- **Postgres function failure:** `AsyncValue.error` renders error message (existing pattern).
- **Missing data:** Function uses `LEFT JOIN` / `COALESCE` to always return valid JSON. Null fields handled by nullable model properties and UI visibility rules.
- **New user (empty state):** `points: {balance:0, locked:0, available:0}`, everything else null/zero. UI shows only the points card.

### 8. Files to Delete

| File | Reason |
|------|--------|
| `payout/presentation/widgets/reward_summary_section.dart` | Replaced by PaymentSummarySection |
| `payout/presentation/reward_summary_controller.dart` (+generated) | Replaced by PaymentSummaryController |
| `payout/domain/reward_summary.dart` (+generated) | Replaced by new models |
| `billing/presentation/widgets/trial_point_wallet_section.dart` | Absorbed into PaymentSummarySection |
| `billing_providers.dart` providers (`trialPointWalletProvider`, `pendingObligationsProvider`) | Remove if unused elsewhere |
| `stripe_payout_repository.dart` `fetchPayoutSummary()` | Replaced by RPC call |

`requestPayout()` and `PayoutAmountDialog` are out of scope (not currently functional, to be addressed separately).

### 9. Testing

**pgTAP tests** in `supabase/tests/database/get_payment_summary.test.sql`:

- User with points only (new user baseline)
- User with active trial points
- User with rewards and exchange rate conversion
- User subscribed (trial null) but obligations remaining
- User with successful payout history (total_earned calculation)
- User with recent payout (various statuses)
- Next payout date accuracy
