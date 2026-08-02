# Remove Realtime, Add Delayed Refresh

**Date:** 2026-04-06

## Problem

The Realtime subscription mechanism in `InAppPurchaseController` does not fire reliably, causing:

1. **UI shows stale data after purchase**: `subscriptionProvider` is not invalidated, so the UI shows "未加入" even when the DB has been updated to `active` by RTDN
2. **"プラン更新中..." persists indefinitely**: The processing state depends on a Realtime callback that never fires
3. **Upgrade shows wrong state**: After upgrading (e.g., light → standard), the UI still shows the old state or "未加入" because the provider cache is stale

Root cause: the Realtime callback in the controller does not fire reliably (under investigation in #328), and the entire processing/refresh mechanism depends on it.

## Design

### Remove

**From `InAppPurchaseController`:**
- `_realtimeChannel` field
- `_subscribeToRealtimeUpdates()` method
- `_removeRealtimeSubscription()` method
- Realtime subscription calls in `buy()` and `restorePurchases()`
- `resetProcessingState()` method (added in PR #329)
- `supabase_flutter` import (was used for Realtime only)
- `billing_providers.dart` import (was used for `subscriptionProvider`/`pointWalletProvider` invalidation in the Realtime callback)

**From `subscription_section.dart`:**
- "プラン更新中..." text display (`purchaseState.value == true` check)
- `isProcessing` parameter on `_PlanCardList`
- `ref.listen(subscriptionProvider, ...)` (added in PR #329)
- `resetProcessingState()` call in `initState`

**From `ja.i18n.json`:**
- `updatingPlan` key ("プラン更新中...")

### Add

**Delayed refresh in `InAppPurchaseController`:**

After `PurchaseStatus.purchased` is processed, fire-and-forget a background polling loop that waits for RTDN to update the DB, then refreshes the UI:

```dart
} else if (purchase.status == PurchaseStatus.purchased) {
  try {
    if (purchase.pendingCompletePurchase) {
      await repo.completePurchase(purchase);
    }
    state = const AsyncData(false);
    _scheduleSubscriptionRefresh();
  } catch (e, st) { ... }
}
```

```dart
Future<void> _scheduleSubscriptionRefresh() async {
  final prevData = ref.read(subscriptionProvider).valueOrNull;
  for (var i = 0; i < 3; i++) {
    await Future.delayed(const Duration(seconds: 3));
    ref.invalidate(subscriptionProvider);
    ref.invalidate(pointWalletProvider);
    final newData = await ref.read(subscriptionProvider.future);
    if (newData?.status != prevData?.status ||
        newData?.planId != prevData?.planId) {
      break;
    }
  }
}
```

This requires re-adding the `billing_providers.dart` import (for `subscriptionProvider`/`pointWalletProvider`), but `supabase_flutter` is no longer needed.

**Behavior:**
- Non-blocking: called fire-and-forget, does not block UI
- Polls up to 3 times at 3-second intervals (max 9 seconds)
- Stops early if subscription data changes (status or planId)
- If RTDN hasn't processed after 9 seconds, UI updates naturally on next screen entry (provider is auto-disposed, re-fetches on re-watch)
- Safe if user navigates away: `ref.invalidate()` on a disposed provider is a no-op

### Files changed

```
peppercheck_flutter/
  assets/i18n/ja.i18n.json                          # MODIFY: remove updatingPlan key
  lib/features/billing/
    presentation/
      in_app_purchase_controller.dart               # MODIFY: remove Realtime, add _scheduleSubscriptionRefresh
      widgets/
        subscription_section.dart                   # MODIFY: remove processing state UI
  lib/gen/slang/                                    # REGENERATE
```

### DB Realtime publication

The `supabase/schemas/subscription/tables/realtime.sql` publication setting stays as-is. It has no performance cost and preserves the option to re-enable Realtime in the future.

### Out of scope

- Realtime root cause investigation (#328)
- Applying delayed refresh pattern to other features (e.g., task creation)
