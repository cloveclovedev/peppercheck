# Subscription UI Redesign

**Issues:** #322, #323, #324, #325
**Date:** 2026-04-03

## Problem

The Payments screen has several UX issues discovered during Google Play IAP testing:

1. **#322**: When a subscription is canceled and expires, the UI shows the old plan name with raw "canceled" status instead of showing "未加入" (no plan)
2. **#323**: No UI to upgrade or downgrade plans, despite `InAppPurchaseController.buy()` already supporting `oldPurchase` and `isUpgrade` parameters
3. **#324**: Google Play product titles include the package name suffix (e.g., "ライトプラン (dev.cloveclove.peppercheck (unreviewed))")
4. **#325**: Plan selection cards lack visual hierarchy and plan differentiation

## Approach

**UI-only change for status display.** The DB `subscription_status` enum and webhook handlers remain unchanged. The `canceled` row stays in `user_subscriptions` to preserve subscription history. A new `SubscriptionDisplayState` sealed class maps DB status to UI display states, keeping the logic testable and exhaustive via compiler checks.

## Design

### SubscriptionDisplayState

A sealed class that derives the UI display state from `Subscription?`:

```dart
sealed class SubscriptionDisplayState {}

/// No active subscription (row null / canceled / incomplete / incomplete_expired)
class NotSubscribed extends SubscriptionDisplayState {}

/// No active subscription + payment issue (unpaid)
class NotSubscribedWithPaymentIssue extends SubscriptionDisplayState {}

/// Active subscription
class ActiveSubscription extends SubscriptionDisplayState {
  final String planId;
  final DateTime periodEnd;
  final bool cancelAtPeriodEnd; // true = "自動更新なし" display
}

/// Active subscription with payment issue (past_due)
class ActiveWithPaymentIssue extends SubscriptionDisplayState {
  final String planId;
  final DateTime periodEnd;
}
```

**Mapping table:**

| DB state | DisplayState |
|---|---|
| null (no row) | `NotSubscribed` |
| `canceled` | `NotSubscribed` |
| `incomplete` / `incomplete_expired` | `NotSubscribed` |
| `unpaid` | `NotSubscribedWithPaymentIssue` |
| `active` (cancelAtPeriodEnd=false) | `ActiveSubscription` |
| `active` (cancelAtPeriodEnd=true) | `ActiveSubscription` (cancelAtPeriodEnd=true) |
| `past_due` | `ActiveWithPaymentIssue` |
| `trialing` / `paused` | `ActiveSubscription` (future-proofing, not currently used) |

The mapping logic lives in a factory method on `SubscriptionDisplayState`, taking `Subscription?` as input.

### Status Display Area

| DisplayState | Icon color | Text | Subtitle |
|---|---|---|---|
| `NotSubscribed` | muted | 「未加入」 | — |
| `NotSubscribedWithPaymentIssue` | muted | 「未加入（お支払いに問題があります）」(warning color) | — |
| `ActiveSubscription` (cancelAtPeriodEnd=false) | plan color | 「{プラン名}」 | 「更新日: {periodEnd}」(secondary, fontSize 12) |
| `ActiveSubscription` (cancelAtPeriodEnd=true) | plan color | 「{プラン名}（自動更新なし）」 | 「終了日: {periodEnd}」(secondary, fontSize 12) |
| `ActiveWithPaymentIssue` | plan color | 「{プラン名}（お支払いに問題があります）」(warning color) | 「更新日: {periodEnd}」(secondary, fontSize 12) |

### Plan Change Flow

**Obtaining current purchase for upgrade/downgrade:**

A new `CurrentPurchase` provider stores the `GooglePlayPurchaseDetails` needed for plan changes:

```dart
@riverpod
class CurrentPurchase extends _$CurrentPurchase {
  @override
  GooglePlayPurchaseDetails? build() => null;

  void set(GooglePlayPurchaseDetails purchase) => state = purchase;
}
```

When `_onPurchaseUpdate` receives a `PurchaseStatus.restored` event with a `GooglePlayPurchaseDetails`, it sets this provider. `restorePurchases()` is called when the subscription section is displayed.

**Upgrade vs downgrade determination:**

Plan order is fixed: `light (0) < standard (1) < premium (2)`. Comparison of `planOrder[newPlanId]` vs `planOrder[currentPlanId]` determines the direction:

- Upgrade (`newOrder > currentOrder`): `ReplacementMode.chargeProratedPrice` (immediate, prorated)
- Downgrade (`newOrder < currentOrder`): `ReplacementMode.deferred` (takes effect at next renewal)

**Flow:**

1. Screen loads → `restorePurchases()` → stream populates `CurrentPurchase`
2. User taps a different plan → compare plan order → determine upgrade/downgrade
3. Call `buy(product: newProduct, oldPurchase: currentPurchase, isUpgrade: isUpgrade)`

### Plan Card UI

**Plan name display (#324):**

Use `product.id` to map to i18n plan names instead of `product.title`:

- `light_monthly` → `t.billing.plans.light`
- `standard_monthly` → `t.billing.plans.standard`
- `premium_monthly` → `t.billing.plans.premium`

Price uses `product.price` as-is (localized by Google Play).

**Card design (#325):**

- **Shape:** Pill-shaped (borderRadius 20), elevation 0 — consistent with PrimaryActionButton
- **Background:** White/light background color
- **Border:** Thin border (`AppColors.border`)
- **Content:** Plan-colored icon (light=green, standard=blue, premium=yellow) + i18n plan name + price
- **Text color:** `AppColors.textPrimary`

**Current plan card:**

- Same shape, background grayed out
- 「現在のプラン」text label displayed
- Tap disabled

**Plan card visibility (all DisplayStates show all 3 plan cards):**

| DisplayState | Active subscription exists | Tap behavior |
|---|---|---|
| `NotSubscribed` / `NotSubscribedWithPaymentIssue` | No | New purchase |
| `ActiveSubscription` / `ActiveWithPaymentIssue` | Yes | Current plan disabled; others trigger upgrade/downgrade |

### File Structure

```
features/billing/
  domain/
    subscription.dart                # Existing (no change)
    subscription_display_state.dart  # NEW: sealed class + factory
  presentation/
    in_app_purchase_controller.dart  # MODIFY: set CurrentPurchase on restored event
    current_purchase_provider.dart   # NEW: GooglePlayPurchaseDetails holder
    widgets/
      subscription_section.dart      # MODIFY: DisplayState-based switch, call restorePurchases
      plan_card.dart                 # NEW: redesigned plan card widget
```

### Out of Scope

- `trialing` / `paused` status: Not currently used by any provider. Mapped to `ActiveSubscription` as a safe default; dedicated handling deferred to when these features are implemented.
- Stripe plan change flow: Stripe checkout is web-based; plan changes for Stripe subscriptions are handled via the web dashboard.
- Webapp changes: The webapp's `dashboard/page.tsx` has similar status display issues but is out of scope for this PR.
