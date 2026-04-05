# Subscription UI Bugfix

**Date:** 2026-04-06
**Related issues:** Found during real-device testing of PR #326

## Problems

### 1. "プラン更新中..." persists indefinitely

After purchasing a subscription, the "プラン更新中..." text never clears. This blocks all plan card interactions (upgrade/downgrade) because `isProcessing = true` disables taps.

**Root cause:** The processing state (`AsyncData(true)`) is stored in a `keepAlive` provider (`InAppPurchaseController`). It is only reset by a one-shot Realtime callback that may not fire reliably. Once stuck, the state persists across screen navigation because the provider is never disposed.

### 2. Cancel display shows "自動更新なし" instead of clear cancellation message

When a subscription is canceled (`cancel_at_period_end = true`), the UI shows "ライトプラン（自動更新なし）" which doesn't clearly communicate that a cancellation was processed.

## Design

### Fix 1: Processing state reset via ref.listen

Add `resetProcessingState()` to `InAppPurchaseController`:

```dart
void resetProcessingState() {
  if (state.value == true) {
    state = const AsyncData(false);
  }
}
```

In `_SubscriptionSectionState.initState()`, use `ref.listen` on `subscriptionProvider` to auto-reset processing state when subscription data changes:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.listen(subscriptionProvider, (prev, next) {
      ref.read(inAppPurchaseControllerProvider.notifier).resetProcessingState();
    });
    ref.read(inAppPurchaseControllerProvider.notifier).resetProcessingState();
    ref.read(inAppPurchaseControllerProvider.notifier).fetchCurrentPurchase();
  });
}
```

**Why this works:**
- Realtime fires → `subscriptionProvider` invalidated → `ref.listen` fires → state reset
- Realtime fails → screen re-entry → `subscriptionProvider` re-fetches from DB → `ref.listen` fires → state reset
- Screen re-entry also calls `resetProcessingState()` directly for immediate reset

### Fix 2: Cancel display text

Change `cancel_at_period_end = true` display from:

| Before | After |
|---|---|
| 「ライトプラン（自動更新なし）」 | 「ライトプラン」 |
| 「終了日: 2026/5/1」 | 「解約済み・2026/5/1まで利用可能」 |

New i18n key: `canceledUntil` = "解約済み・{date}まで利用可能"

### Files changed

```
peppercheck_flutter/
  assets/i18n/ja.i18n.json                          # MODIFY: add canceledUntil key
  lib/features/billing/presentation/
    in_app_purchase_controller.dart                  # MODIFY: add resetProcessingState()
    widgets/subscription_section.dart                # MODIFY: ref.listen + cancel display
  lib/gen/slang/                                     # REGENERATE
```

### Out of scope

- Realtime debugging (tracked in issue #328)
- Root cause investigation of why Realtime callback doesn't fire
