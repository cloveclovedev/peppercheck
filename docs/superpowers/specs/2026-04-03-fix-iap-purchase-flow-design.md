# Fix IAP Purchase Flow — Design Spec

## Problem

Two issues discovered during Google Play IAP testing (PR #317):

### 1. Overlay spinner blocks UI unnecessarily

`InAppPurchaseController.buy()` sets `state = AsyncLoading()`, which triggers a full-screen black overlay with spinner on the subscription section. This is unnecessary because Google Play's own purchase dialog is already displayed in the foreground.

### 2. Realtime subscription race condition

After `completePurchase()`, the controller subscribes to Supabase Realtime to detect the DB update from the RTDN chain. However, the RTDN chain (Google Play → Pub/Sub → Edge Function → DB) can complete **before** the Realtime channel finishes subscribing. Since Realtime only delivers changes that occur after subscription, the client misses the update. The `state` remains `AsyncLoading` forever, and `keepAlive: true` preserves this stale state across navigation.

The RTDN chain itself works correctly — the DB was updated and the subscription data was visible after re-fetching via `subscriptionProvider`.

## Design

### Remove overlay spinner

- Remove `state = const AsyncLoading()` from `buy()`.
- Remove the `Positioned.fill` overlay widget from `subscription_section.dart`.
- Remove the `isPurchasing` variable and related `purchaseState` watch from the build method.
- Keep `purchaseState.hasError` for displaying purchase errors inline.

### Fix Realtime race condition

Subscribe to Realtime **before** initiating the purchase, not after `completePurchase()`.

Updated flow:

```
1. User taps buy button
2. _subscribeToRealtimeUpdates()    ← subscribe FIRST
3. repo.buySubscription()           ← then start purchase
4. Google Play dialog appears
5. User confirms purchase
6. purchaseStream fires PurchaseStatus.purchased
7. completePurchase()
8. (Realtime callback may fire at any point after step 2)
```

This eliminates the race condition because the Realtime channel is listening before Google even knows about the purchase.

### Inline "プラン更新中" indicator

After `completePurchase()` succeeds, set a lightweight flag (`_awaitingPlanUpdate`) instead of using `AsyncLoading`. This flag drives a subtle inline text "プラン更新中..." below the subscription status, replacing the heavy overlay.

Controller changes:
- Change state type from `AsyncValue<void>` to `AsyncValue<bool>`. The bool represents "awaiting plan update" (`true` = waiting for RTDN, `false` = idle). This ensures state changes are reactive — a plain field on the notifier is not observable by Riverpod.
- `build()` returns `false` (initial idle state).
- Set `state = AsyncData(true)` after `completePurchase()` in `_onPurchaseUpdate`.
- Set `state = AsyncData(false)` when Realtime callback fires.
- No timeout — if the state stays `true`, it correctly indicates the RTDN chain has not completed. This is a real problem that should be visible, not hidden.

UI changes:
- In `subscription_section.dart`, watch `inAppPurchaseControllerProvider` and check `purchaseState.value == true`.
- When `true`, show a small `Text` with `t.billing.updatingPlan` below the subscription status row.
- When `false` (or Realtime fires), the text disappears and `subscriptionProvider` shows updated data.

### i18n

Update `ja.i18n.json`:
- Change `processingPurchase` → `updatingPlan`: `"プラン更新中..."`

(The old key `processingPurchase` is no longer used after removing the overlay.)

## Files to modify

| File | Change |
|------|--------|
| `in_app_purchase_controller.dart` | Remove `AsyncLoading` from `buy()`, add `_awaitingPlanUpdate` flag, move Realtime subscribe before purchase, expose awaiting state |
| `subscription_section.dart` | Remove overlay spinner, add inline "プラン更新中" text |
| `ja.i18n.json` | Replace `processingPurchase` with `updatingPlan` |
| Generated slang files | Regenerate after i18n change |

## Out of scope

- UI/UX redesign of subscription buttons and cards (separate PR)
- RTDN Edge Function error handling / retry strategy (separate issue)
- Stripe webhook flow (unaffected)

## Re-test procedure (production)

### Prerequisites
- License tester account in "PepperCheck Internal Testers" mailing list
- Test device with the tester account as primary Google account
- Deploy fixed build to internal test track

### Steps

1. **Clean state**: If previous test subscription exists, cancel it from Google Play subscription management and wait for expiry (~30 min for test subscriptions, or check Google Play subscription status).

2. **Deploy**:
   ```bash
   # Merge fix to main, then:
   git checkout beta/v1.0
   git merge main
   git push origin beta/v1.0
   ```
   Wait for `deploy-beta` workflow to complete. Download APK from Firebase App Distribution and install on test device.

3. **Test: New purchase**
   - Open Payments screen
   - Tap a plan button (e.g., ライトプラン ¥650)
   - Google Play dialog appears → tap "Subscribe"
   - Verify: No overlay spinner appears
   - Verify: "プラン更新中..." text appears briefly below subscription status
   - Verify: Subscription status updates to show the plan name and renewal date
   - Check Edge Function logs: `supabase functions logs handle-google-play-rtdn`
   - Check DB: `user_subscriptions` row exists with correct `plan_id`, `status=active`

4. **Test: Auto-renewal** (wait ~5 min for test subscription renewal)
   - Verify: Points granted (check `point_ledger`)
   - Verify: Idempotency — same `invoice_id` doesn't grant double points

5. **Test: Cancellation**
   - Cancel subscription from Google Play subscription management
   - Verify: `cancel_at_period_end = true` in DB
   - Verify: Status remains `active` until expiry

6. **Test: Expiry**
   - Wait for subscription to expire after cancellation
   - Verify: `status` changes to `canceled`

7. **Test: Navigate away and back**
   - During "プラン更新中" state, navigate to Home tab and back to Payments
   - Verify: No stuck spinner, subscription state shows correctly
