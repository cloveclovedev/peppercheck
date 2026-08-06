# Google Play In-App Purchase Subscription Integration Design

Related: [Issue #300](https://github.com/mkuri/peppercheck/issues/300)

## Overview

Implement Google Play In-App Purchase (IAP) for subscription purchases on Android. Google Play policy requires digital goods to use Google Play Billing. The app already has basic `in_app_purchase` Flutter code, but the backend lifecycle management and purchase flow need to be built out.

The design follows a single-backend-handler approach: all subscription lifecycle events (purchase, renewal, cancellation, expiry, etc.) are processed by a new `handle-google-play-rtdn` Edge Function that receives Google Play Real-time Developer Notifications (RTDN) via Cloud Pub/Sub. This mirrors the existing `handle-stripe-webhook` pattern.

## Architecture

### Purchase Flow

```
User taps "Subscribe" in Flutter
  → Google Play Billing dialog
  → Purchase completes
  → Flutter calls completePurchase() (acknowledges to Google)
  → subscription_section shows "processing" state
  → Google Play sends RTDN via Pub/Sub push
  → handle-google-play-rtdn Edge Function receives notification
  → Calls subscriptionsv2.get for full subscription state
  → Identifies user via externalAccountIdentifiers.obfuscatedExternalAccountId
  → Upserts user_subscriptions, grants points, deactivates trial points
  → Flutter detects change via Supabase Realtime → UI updates
```

### User Identification

The Flutter client sets `applicationUserName: user.id` (Supabase UUID) when initiating a purchase. This is passed to Google Play as `obfuscatedAccountId`. When the RTDN handler calls `subscriptionsv2.get`, the response includes:

```json
{
  "externalAccountIdentifiers": {
    "obfuscatedExternalAccountId": "<Supabase user UUID>"
  }
}
```

This eliminates the need for a pre-registration step or database reverse lookup. All notification types can identify the user through this mechanism.

## Google Play Console Setup (Manual)

### Subscription Products

Create 3 subscription products in Play Console > Monetize > Subscriptions:

| Product ID | Name | Base Plan | Price (JPY) |
|---|---|---|---|
| `light_monthly` | ライト | Monthly auto-renewing | 650 |
| `standard_monthly` | スタンダード | Monthly auto-renewing | 1,280 |
| `premium_monthly` | プレミアム | Monthly auto-renewing | 2,580 |

- All 3 subscriptions belong to a single subscription group with tier ordering: light < standard < premium (enables upgrade/downgrade)
- No free trial offers (covered by Freemium v1 trial points)
- Prices assume 30% commission rate; at the 15% tier (under $1M/year), this increases margin rather than requiring a future price increase

### Service Account & API Access

1. Create a service account in Google Cloud Console (or verify existing one)
2. Enable the **Android Publisher API**
3. Link the service account in Play Console > Setup > API access with permissions:
   - View app information and download bulk reports
   - View financial data, orders, and cancellation survey responses
   - Manage orders and subscriptions
4. Store the service account JSON key as `GOOGLE_SERVICE_ACCOUNT_JSON` in Supabase secrets (may already exist — verify)

### RTDN (Real-time Developer Notifications)

1. Enable **Cloud Pub/Sub API** in Google Cloud Console
2. Create a Pub/Sub topic (e.g., `play-subscription-notifications`)
3. Grant `google-play-developer-notifications@system.gserviceaccount.com` the **Pub/Sub Publisher** role on the topic
4. Create a **push subscription**:
   - Endpoint: `https://<project-ref>.supabase.co/functions/v1/handle-google-play-rtdn`
   - Authentication: Enable OIDC token (specify service account, audience = endpoint URL)
5. In Play Console > Monetize > Monetization setup > Real-time developer notifications, set the topic name
6. Verify with "Send test notification"

## Backend — `handle-google-play-rtdn` Edge Function

### Authentication

- `verify_jwt = false` in `config.toml` (request comes from Pub/Sub, not a user)
- Verify the Pub/Sub push OIDC token using `jose` (already a project dependency):
  - Validate `aud` matches the Edge Function URL
  - Validate `iss` is `https://accounts.google.com`
  - Validate `email` matches the push subscription's service account
  - Validate `email_verified` is `true`

### Message Processing

1. Verify OIDC token
2. Parse the Pub/Sub envelope: `message.data` is base64-encoded
3. Decode to get `DeveloperNotification` with `subscriptionNotification.notificationType` and `subscriptionNotification.purchaseToken`
4. If `testNotification` is present, log and return 200 (test message from Play Console)
5. Call `subscriptionsv2.get` with the `purchaseToken` to get the current subscription state (notifications are signals, not data — always fetch current state)
6. Extract `user_id` from `externalAccountIdentifiers.obfuscatedExternalAccountId`
7. Extract `plan_id` from `lineItems[0].productId`
8. Process based on notification type (see table below)
9. Return HTTP 200 (ACK). Any non-2xx causes Pub/Sub retry with exponential backoff.

**Always return 200**, even for messages that are skipped or have non-fatal errors. Returning 4xx/5xx causes infinite retries.

### Notification Type Handling

| Code | Type | Action |
|---|---|---|
| 4 | `SUBSCRIPTION_PURCHASED` | Upsert `user_subscriptions` (status: active), call `grant_subscription_points`, call `deactivate_trial_points` |
| 2 | `SUBSCRIPTION_RENEWED` | Upsert `user_subscriptions` (update period dates), call `grant_subscription_points` |
| 3 | `SUBSCRIPTION_CANCELED` | Update `cancel_at_period_end = true` (access maintained until expiry) |
| 13 | `SUBSCRIPTION_EXPIRED` | Upsert `user_subscriptions` (status: canceled) |
| 5 | `SUBSCRIPTION_ON_HOLD` | Upsert `user_subscriptions` (status: unpaid) — access revoked |
| 6 | `SUBSCRIPTION_IN_GRACE_PERIOD` | Upsert `user_subscriptions` (status: past_due) — access maintained |
| 1 | `SUBSCRIPTION_RECOVERED` | Upsert `user_subscriptions` (status: active) |
| 12 | `SUBSCRIPTION_REVOKED` | Upsert `user_subscriptions` (status: canceled) — immediate access revocation |

Google Play status → existing `subscription_status` enum mapping:
- `ON_HOLD` → `unpaid`
- `IN_GRACE_PERIOD` → `past_due`
- No new enum values needed.

### Idempotency

`grant_subscription_points` already checks for duplicate `p_invoice_id` in `point_ledger`. For Google Play, pass `google:{purchaseToken}:{expiryTime}` as the invoice_id equivalent. Using `expiryTime` (not `notificationType`) ensures each renewal period gets a unique key, since `purchaseToken` remains the same for the life of the subscription. This prevents double point grants when Pub/Sub redelivers the same message, while correctly granting points for each renewal.

### Google Play API Authentication

Extract the `getGoogleAccessToken()` utility from `verify-google-purchase` before deleting it. This function performs service account JWT → OAuth2 token exchange to call `subscriptionsv2.get`:

```
GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptionsv2/tokens/{token}
```

### Subscription Upsert

The `user_subscriptions` upsert sets:
- `user_id`: from `externalAccountIdentifiers`
- `plan_id`: from `lineItems[0].productId`
- `status`: mapped from notification type
- `provider`: `'google'`
- `google_purchase_token`: from notification
- `current_period_start`: from `startTime` (top-level field in v2 response)
- `current_period_end`: from `lineItems[0].expiryTime`
- `cancel_at_period_end`: from `lineItems[0].autoRenewingPlan` presence

## DB Changes

### Minimal

- No new tables
- No new enum values
- `supabase/config.toml`: remove `verify-google-purchase`, add `handle-google-play-rtdn` with `verify_jwt = false`

### Cleanup

Delete `verify-google-purchase`:
1. `supabase functions delete verify-google-purchase` (remove deployed function)
2. Delete `supabase/functions/verify-google-purchase/` directory
3. Remove from `supabase/config.toml`

## Flutter Changes

### Purchase Flow (`InAppPurchaseRepository`)

- Delete `verifyPurchase()` method
- Update `buySubscription()` to set `applicationUserName: user.id` when creating `PurchaseParam` / `GooglePlayPurchaseParam`

### Purchase Lifecycle (`InAppPurchaseController`)

- Remove `verifyPurchase()` call from `_onPurchaseUpdate`
- After `completePurchase()`, maintain "processing" state in `subscription_section` only (do not block other app operations)
- Subscribe to `user_subscriptions` table changes via Supabase Realtime
- When subscription status changes to `active`, update UI

### Subscription UI (`subscription_section.dart`)

- Uncomment `_ProductList` widget
- Fetch available products via `in_app_purchase` package (prices come from Play Store)
- Add purchase button for each plan
- Show "processing" indicator after purchase until Realtime update received

### Upgrade/Downgrade

When the user has an active Google subscription and selects a different plan:
- Use `GooglePlayPurchaseParam` with `changeSubscriptionParam`
- Upgrade (lower → higher tier): `ReplacementMode.chargeProrationPrice`
- Downgrade (higher → lower tier): `ReplacementMode.deferred`

### Restore Purchases

Add `InAppPurchase.instance.restorePurchases()` functionality for app reinstall scenarios.

## Trial Point Integration

On `SUBSCRIPTION_PURCHASED`:
1. `grant_subscription_points(user_id, amount, invoice_id)` — grants monthly points for the purchased plan
2. `deactivate_trial_points(user_id)` — sets `trial_point_wallets.is_active = false`

This matches the existing `handle-stripe-webhook` behavior. Both RPCs are idempotent.

`deactivate_trial_points` is best-effort: if it fails, the RTDN handler still returns 200 (subscription activation is primary). Trial deactivation can be retried on the next notification.

## Testing

### License Testers

Add tester Google accounts in Play Console > Setup > License testing. Test subscriptions:
- Monthly plans renew every 5 minutes (max 6 renewals, then expire)
- No real charges with test payment instruments
- Debug builds can be sideloaded (no Play Store download required)

### Test Scenarios

1. **New purchase**: Purchase → RTDN `PURCHASED` → subscription active → points granted → trial points deactivated
2. **Renewal**: Auto-renewal after 5 min → RTDN `RENEWED` → points granted (idempotency verified)
3. **Cancellation**: Cancel from Play Store → RTDN `CANCELED` → `cancel_at_period_end = true`
4. **Expiry**: After cancellation period → RTDN `EXPIRED` → status canceled
5. **Upgrade/downgrade**: light → standard → correct plan switch
6. **Restore**: Reinstall → `restorePurchases()` → subscription state restored

### RTDN Verification

Use Play Console's "Send test notification" to verify the Edge Function receives and logs `testNotification` messages.
