# iOS In-App Purchase Subscription Integration Design

Related: [Issue #402](https://github.com/cloveclovedev/peppercheck/issues/402)

## Overview

Mirror the existing Google Play IAP integration on iOS so that subscription purchases from iOS builds go through Apple StoreKit and **App Store Server Notifications V2 (ASSN V2)**.

The design follows the same single-backend-handler pattern as the Android counterpart: all subscription lifecycle events are processed by a new `handle-app-store-server-notification` Edge Function that receives ASSN V2 notifications directly from Apple. Unlike Google Play (where notifications are signals and the Server API holds the truth), Apple's notifications include the **full signed transaction state** in the payload itself, so the handler verifies the JWS chain and consumes the payload directly without an additional Server API call.

## Architecture

### Purchase Flow

```
[Flutter on iOS]
   │ ① ProductDetails fetch (queryProductDetails)
   ↓
[Apple StoreKit] (App Store Connect-configured products)
   │ ② Buy request (applicationUserName: user.id)
   │ ③ Apple billing UI → purchase complete
   ↓
[Flutter on iOS]
   │ ④ purchaseStream emits PurchaseDetails → completePurchase()
   │ ⑤ subscription_section shows "processing" state
   │ ⑥ _scheduleSubscriptionRefresh() starts progressive polling
   │   (1s, 1s, 2s, 2s, 3s — invalidates subscriptionProvider)
   │
   ↓ (parallel)
[Apple ASSN V2 server]
   │ ⑦ HTTPS POST { signedPayload: "<JWS>" }
   ↓
[Edge Function: handle-app-store-server-notification]
   │ ⑧ Verify JWS (x5c chain → Apple Root CA, via app-store-server-library)
   │ ⑨ Verify and decode signedTransactionInfo / signedRenewalInfo (nested JWS)
   │ ⑩ Identify user via transactionInfo.appAccountToken
   │ ⑪ Upsert user_subscriptions
   │ ⑫ Call reset_subscription_points() RPC (idempotent)
   │ ⑬ Call deactivate_trial_points() RPC (on SUBSCRIBED only)
   │ ⑭ Always return HTTP 200
   ↓
[Supabase DB]
   │ user_subscriptions updated
   ↓ (Flutter polling picks up the change)
[Flutter on iOS]
   ⑮ subscriptionProvider re-reads → UI reflects new state
```

### User Identification

The Flutter client sets `applicationUserName: user.id` (Supabase UUID) when initiating a purchase (`in_app_purchase_repository.dart:46-50`, already present in the `else` branch). The `in_app_purchase_storekit` plugin maps this to Apple StoreKit's `appAccountToken` field, which is included in `signedTransactionInfo` in every ASSN V2 notification. The Edge Function reads `appAccountToken` to identify the Supabase user — no pre-registration or reverse lookup is needed.

### Comparison with Other Providers

| Provider | Notification source | Source of truth | User identification |
|---|---|---|---|
| Stripe | Webhook | Webhook payload (signed) | `customer.metadata.user_id` |
| Google Play | RTDN via Pub/Sub | `subscriptionsv2.get` Server API | `obfuscatedExternalAccountId` |
| Apple | ASSN V2 (direct HTTPS) | Notification payload itself (JWS-verified) | `appAccountToken` |

Apple's design lets us skip the Server API roundtrip because the notification payload is signed and complete. This eliminates the need for an App Store Server API key (`.p8`) and reduces operational dependencies.

## App Store Connect Setup (Manual)

### Apple Developer Portal — App ID Registration

1. Apple Developer Portal → Identifiers → Register an App ID
2. **Bundle ID**: `dev.cloveclove.peppercheck` (Explicit)
3. **Description**: `PepperCheck`
4. **Capabilities** to enable:
   - **In-App Purchase**
   - **Push Notifications** (for existing FCM)
   - Other capabilities and App Services / Capability Requests tabs are not needed
5. Note: **Sign In with Apple** is required for production App Store submission (Apple App Review Guideline 4.8) but is out of scope here. Tracked separately in #413.

### App Store Connect — App Record

App Store Connect → My Apps → New App:

- **Platforms**: iOS only
- **Name**: PepperCheck
- **Primary Language**: Japanese
- **Bundle ID**: `dev.cloveclove.peppercheck`
- **SKU**: `dev.cloveclove.peppercheck` (matches Bundle ID for simplicity)
- **User Access**: Full Access

### Subscription Products

App → Monetization → Subscriptions:

#### Subscription Group

- **Reference Name**: `main_subscription`
- **Display Name (ja)**: `プラン`

#### Products in the group

| Product ID | Reference Name | Group Level | Price (JPY) | Family Sharing |
|---|---|---|---|---|
| `premium_monthly` | Premium Monthly | 1 (highest) | 2,480 | OFF |
| `standard_monthly` | Standard Monthly | 2 | 1,280 | OFF |
| `light_monthly` | Light Monthly | 3 (lowest) | 650 | OFF |

All products:
- **Subscription Duration**: 1 month
- **Auto-Renewable**: ON
- **Free Trial / Introductory Offer**: not configured (trial points cover this need)

> Group Level ordering matters: Apple uses `Level 1 = highest service level`. Upgrade (lower → higher) is immediate with prorated billing; downgrade (higher → lower) takes effect at period end.

Localization (Japanese) per product:

| Product | Display Name | Description |
|---|---|---|
| Light | ライトプラン | 毎月5ポイントが付与されます。 |
| Standard | スタンダードプラン | 毎月10ポイントが付与されます。 |
| Premium | プレミアムプラン | 毎月20ポイントが付与されます。 |

> Description is currently minimal. As plan-level feature differentiation evolves, descriptions will be updated (Apple allows post-publish edits).

Availability: **Japan only**.

> Once products are created, ASC product status will show "Missing Metadata" until each has Subscription Price + Localization + Availability + (eventually for production review) a Review Screenshot. Sandbox testing does not require the Review Screenshot — the missing-metadata state is expected during the Issue #402 scope.

### App Store Server Notifications V2 (ASSN) Endpoint

App → App Information → App Store Server Notifications:

- **Version**: 2 (V2)
- **Production Server URL**: `https://<production-project-ref>.supabase.co/functions/v1/handle-app-store-server-notification`
- **Sandbox Server URL**: `https://<staging-project-ref>.supabase.co/functions/v1/handle-app-store-server-notification`
- After saving, click **Send Test Notification** to verify endpoint reachability.
- The legacy V1 "Subscription Status URL" is left empty.

### Sandbox Testers

App Store Connect → Users and Access → Sandbox → Testers:

- Create at least one Sandbox tester with a fresh email address (typically `+sandbox` plus-aliased)
- Country/Region: Japan
- Sign in on the iOS test device via Settings → App Store → Sandbox Account
- Sandbox subscriptions renew every 5 minutes (max 6 renewals, then auto-expire) — useful for renewal testing

### Manual Steps Out of Scope

These are not part of #402 but will be needed before production submission:

- Per-product Review Screenshot (3 screenshots, of the plan-selection UI)
- App-level App Store screenshots (each iOS size class)
- Review Notes (instructions for the reviewer to test purchases)
- Age rating, content rights, export compliance
- Privacy / Terms URL registration (existing webapp URLs)

## Backend — `handle-app-store-server-notification` Edge Function

### Files

Generated by `supabase functions new handle-app-store-server-notification`:

```
supabase/functions/handle-app-store-server-notification/
├── index.ts
├── deno.json
└── .npmrc
```

Update `supabase/config.toml` to register the new function with `verify_jwt = false` (notifications come directly from Apple, not from a logged-in user).

### Dependencies

- `@supabase/supabase-js` (existing)
- `npm:@apple/app-store-server-library` — Apple's official SDK that handles JWS verification including the x5c certificate chain check up to Apple Root CA. Pulled via `npm:` specifier in Deno.

If the npm-on-Deno integration causes issues, fallback to `jose` + a hand-rolled X.509 chain validator (Q5 alt). This is a known risk, addressed during implementation.

### Authentication

There is no JWT to verify (notification is not from a user). Authenticity is established by **JWS signature verification**:

1. The HTTP body is `{ signedPayload: "<JWS>" }`.
2. `SignedDataVerifier.verifyAndDecodeNotification(signedPayload)` from `app-store-server-library`:
   - Decodes the JWS header
   - Walks the `x5c` certificate chain to Apple Root CA (root cert is bundled in the SDK)
   - Verifies the leaf signature
   - Returns the decoded notification payload
3. Nested JWS fields `signedTransactionInfo` and `signedRenewalInfo` are similarly decoded with `verifyAndDecodeTransaction()` and `verifyAndDecodeRenewalInfo()`.
4. Bundle ID and environment (Sandbox/Production) are checked against the SDK's expected values.

### Main Handler Sketch

```typescript
import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'
import { createClient } from '@supabase/supabase-js'
import {
  SignedDataVerifier,
  Environment,
} from 'npm:@apple/app-store-server-library'

const BUNDLE_ID = Deno.env.get('APPLE_BUNDLE_ID') ?? 'dev.cloveclove.peppercheck'
const ENVIRONMENT = Deno.env.get('APPLE_ENVIRONMENT') === 'Production'
  ? Environment.PRODUCTION
  : Environment.SANDBOX

// Apple Root CA certs are bundled with app-store-server-library; pass them in
const verifier = new SignedDataVerifier(
  appleRootCAs,    // bundled with SDK
  true,             // enableOnlineChecks (CRL/OCSP)
  ENVIRONMENT,
  BUNDLE_ID,
)

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  try {
    const body = await req.json()
    const decoded = await verifier.verifyAndDecodeNotification(body.signedPayload)
    const { notificationType, subtype, data } = decoded

    if (data.environment) {
      console.log(`environment=${data.environment} type=${notificationType} subtype=${subtype ?? '-'}`)
    }

    const transactionInfo = await verifier.verifyAndDecodeTransaction(
      data.signedTransactionInfo,
    )
    const renewalInfo = data.signedRenewalInfo
      ? await verifier.verifyAndDecodeRenewalInfo(data.signedRenewalInfo)
      : null

    const userId = transactionInfo.appAccountToken
    if (!userId) {
      console.error('appAccountToken missing — skipping')
      return new Response(JSON.stringify({ received: true }), { status: 200 })
    }

    await handleNotification({
      notificationType,
      subtype,
      transactionInfo,
      renewalInfo,
      userId,
      supabaseAdmin,
    })

    return new Response(JSON.stringify({ received: true }), { status: 200 })
  } catch (err) {
    console.error('Error processing ASSN:', err)
    // Always 200 — Apple retries up to 5 times over 3 days on non-2xx
    return new Response(JSON.stringify({ error: 'processing failed' }), { status: 200 })
  }
})
```

### Notification Type Handling

| `notificationType` | `subtype` | Action | `subscription_status` |
|---|---|---|---|
| `SUBSCRIBED` | `INITIAL_BUY` | upsert + reset_subscription_points + deactivate_trial_points | `active` |
| `SUBSCRIBED` | `RESUBSCRIBE` | upsert + reset_subscription_points | `active` |
| `DID_RENEW` | (any) | upsert + reset_subscription_points | `active` |
| `DID_FAIL_TO_RENEW` | `GRACE_PERIOD` | upsert (period extended by Apple) | `past_due` |
| `DID_FAIL_TO_RENEW` | (none) | upsert | `past_due` |
| `EXPIRED` | (any subtype) | upsert | `canceled` |
| `GRACE_PERIOD_EXPIRED` | — | upsert | `canceled` |
| `DID_CHANGE_RENEWAL_STATUS` | `AUTO_RENEW_DISABLED` | set `cancel_at_period_end = true` | (unchanged) |
| `DID_CHANGE_RENEWAL_STATUS` | `AUTO_RENEW_ENABLED` | set `cancel_at_period_end = false` | (unchanged) |
| `DID_CHANGE_RENEWAL_PREF` | — | upsert (plan change) | (unchanged) |
| `REFUND` | — | upsert | `canceled` |
| `REVOKE` | — | upsert | `canceled` |
| `PRICE_INCREASE` | — | log only | (unchanged) |
| `TEST` | — | log only, return 200 | — |

Mapping to existing `subscription_status` enum requires no new enum values. `unpaid` (used by Google Play `ON_HOLD`) has no direct Apple counterpart — Apple's `EXPIRED` covers terminal failure.

### Idempotency

When calling `reset_subscription_points(p_user_id, p_amount, p_invoice_id)`, pass:

```
apple:{transactionId}
```

Each Apple transaction (initial purchase or renewal) has a unique `transactionId`, so this naturally deduplicates retries. The existing `point_ledger.invoice_id` uniqueness check enforces idempotency.

### Subscription Upsert

```typescript
// Apple productId is '{planId}_monthly', DB plan IDs are '{planId}'
// (mirrors extractPlanId in handle-google-play-rtdn)
function extractPlanId(productId: string): string {
  return productId.replace('_monthly', '')
}

await supabaseAdmin.from('user_subscriptions').upsert({
  user_id: userId,
  plan_id: extractPlanId(transactionInfo.productId), // "light_monthly" → "light"
  status: mappedStatus,
  provider: 'apple',
  apple_original_transaction_id: transactionInfo.originalTransactionId,
  current_period_start: new Date(transactionInfo.purchaseDate).toISOString(),
  current_period_end: new Date(transactionInfo.expiresDate).toISOString(),
  cancel_at_period_end: renewalInfo?.autoRenewStatus === 0, // 0 = off, 1 = on
  updated_at: new Date().toISOString(),
})
```

Notes:
- The `extractPlanId` helper mirrors the Google Play handler's existing logic at `supabase/functions/handle-google-play-rtdn/index.ts:109-112`. Apple `productId` (`light_monthly`) is normalized to the DB `plan_id` (`light`) the same way as Google Play `lineItems[0].productId`.
- `originalTransactionId` is stored for record-keeping and future Server API queries (e.g. if we ever switch to the A pattern).
- `transactionInfo.purchaseDate` and `transactionInfo.expiresDate` are millisecond UTC timestamps from the SDK.

### Environment Variables

| Env Var | Used by | Value |
|---|---|---|
| `APPLE_BUNDLE_ID` | Edge Function | `dev.cloveclove.peppercheck` |
| `APPLE_ENVIRONMENT` | Edge Function | `Sandbox` (staging) or `Production` (prod) |

These are set via `supabase secrets set` per environment.

### Why Always Return 200

Apple ASSN retries on any non-2xx response with exponential backoff over 3 days, up to 5 times. Returning 5xx causes infinite retry loops and noisy logs. Failed processing is logged for manual investigation, mirroring the Google Play RTDN handler's policy.

### Reused RPCs

No new RPCs are needed. Existing functions are sufficient and already idempotent:

- `reset_subscription_points(p_user_id, p_amount, p_invoice_id)` — grants/resets monthly points
- `deactivate_trial_points(p_user_id)` — sets `trial_point_wallets.is_active = false`

## DB Changes

### Schema Edits

`supabase/schemas/subscription/tables/user_subscriptions.sql`:

```sql
-- New column
apple_original_transaction_id text,

-- New index (after existing indexes)
CREATE INDEX idx_user_subscriptions_apple_id
    ON public.user_subscriptions USING btree (apple_original_transaction_id);
```

The `subscription_provider` enum already includes `'apple'` — no enum change needed.

### Migration Generation

Per `.claude/rules/supabase-workflow.md`:

1. Edit `supabase/schemas/subscription/tables/user_subscriptions.sql` (add column + index above).
2. Run `supabase db diff -f add_apple_iap_support` to auto-generate the DDL migration.
3. Manually append the DML statements (db diff does not detect inserts/updates):

```sql
-- DML, not detected by schema diff

-- Apple subscription prices
INSERT INTO public.subscription_plan_prices (plan_id, currency_code, amount_minor, provider)
VALUES
    ('light', 'JPY', 650, 'apple'),
    ('standard', 'JPY', 1280, 'apple'),
    ('premium', 'JPY', 2480, 'apple')
ON CONFLICT (plan_id, currency_code, provider) DO UPDATE SET
    amount_minor = EXCLUDED.amount_minor;

-- Align Google Play premium price with Apple (Issue #411)
UPDATE public.subscription_plan_prices
SET amount_minor = 2480
WHERE plan_id = 'premium' AND provider = 'google';
```

4. Run `./scripts/db-reset-and-clear-android-emulators-cache.sh` to verify migration history works from scratch.

### Why External IDs Stay in Separate Columns

The existing `stripe_subscription_id` / `google_purchase_token` design is kept as-is; `apple_original_transaction_id` is added alongside. Reasons:

- Provider count is bounded (3 max in foreseeable future)
- Each provider's ID format and semantics differ (Stripe entity ID, Google purchase token, Apple originalTransactionId) — naming makes intent obvious
- Direct DB inspection during operations is easier with named columns
- Indexes per column give clean per-provider lookup

### Tests

Per `.claude/rules/db-testing.md` (pgTAP):

- `supabase/tests/database/test_user_subscriptions_apple_column.sql`
  - Column `apple_original_transaction_id` exists with type text, nullable
  - Index `idx_user_subscriptions_apple_id` exists
  - Insert/select roundtrip on an Apple-provider row succeeds
- `supabase/tests/database/test_subscription_plan_prices_apple.sql`
  - Three Apple rows exist with expected JPY amounts (650 / 1280 / 2480)
  - Google premium row equals 2480 (Issue #411 alignment)

After migration + new tests, run the full pgTAP suite to ensure no regressions.

### Google Play Console Manual Step (parallel work)

To complete Issue #411 alignment:

- Play Console → Monetize → Subscriptions → `premium_monthly` → Pricing → set to ¥2,480
- No grace-period notification needed (zero current paying users)

## Flutter Changes

### Already in place (no change)

- `in_app_purchase_repository.buySubscription()` already sets `applicationUserName: user.id` for the non-Android branch (lines 46-50)
- `availableProductsProvider` uses product IDs `light_monthly` / `standard_monthly` / `premium_monthly` (cross-platform)
- `_scheduleSubscriptionRefresh()` progressive polling is platform-agnostic
- `restorePurchases()` plumbing exists in `InAppPurchaseRepository` and `InAppPurchaseController` (just not wired to UI yet)

### Cancel link platform branching

`peppercheck_flutter/lib/features/billing/presentation/widgets/plan_selection_bottom_sheet.dart` (around line 96):

```dart
final cancelUrl = Platform.isIOS
    ? 'https://apps.apple.com/account/subscriptions'
    : 'https://play.google.com/store/account/subscriptions';

final cancelLabel = Platform.isIOS
    ? t.billing.cancelViaAppStore
    : t.billing.cancelViaGooglePlay;
```

i18n additions in `peppercheck_flutter/assets/i18n/ja.i18n.json`:

```json
"cancelViaAppStore": "キャンセルはApp Storeから →"
```

### "Restore Purchases" link in SupportSection (iOS only)

`peppercheck_flutter/lib/features/account/presentation/widgets/support_section.dart`:

- Convert `SupportSection` from `StatelessWidget` to `ConsumerWidget` (needs `WidgetRef`)
- Add a new `_LinkTile` for `t.billing.restorePurchases` between the privacy policy and contact rows
- Render only when `Platform.isIOS`
- onTap behavior:
  1. Call `inAppPurchaseControllerProvider.notifier.restorePurchases()`
  2. Invalidate `subscriptionProvider`
  3. Show SnackBar with success/failure copy

i18n additions:

```json
"restorePurchases": "購入を復元",
"restoreSucceeded": "購入を復元しました",
"restoreFailed": "購入の復元に失敗しました"
```

This satisfies Apple App Review Guideline 3.1.1 (subscription apps must offer a Restore Purchases mechanism). Android does not need it (Play Store auto-restores), so it is iOS-gated to keep the UI clean.

If a production review reject lands due to discoverability, fall back to also placing a smaller link in `subscription_section.dart` or in the plan-selection bottom sheet.

### `in_app_purchase_storekit` behavior verification (during implementation)

Confirm during real Sandbox testing on a physical device:

- `applicationUserName: user.id` reaches the Apple ASSN payload as `appAccountToken` (UUID format)
- If it does not (older versions of `in_app_purchase_storekit` may not pass UUIDs through), implement a Method Channel fallback that calls StoreKit2's `Product.purchase(options:)` with explicit `.appAccountToken(UUID)`.

### iOS `purchaseStream` quirks

The current `_onPurchaseUpdate` implementation handles `PurchaseStatus.restored` for Android (storing the GooglePlayPurchaseDetails for later upgrade flow). On iOS, restored purchases also arrive with `restored` status but the underlying type is `AppStorePurchaseDetails`, not `GooglePlayPurchaseDetails`. Behavior to verify in testing:

- Restored iOS purchases should not flip controller state (they're not new buys)
- `pendingCompletePurchase` should be honored to acknowledge the purchase to StoreKit

If any divergence appears, branch on `purchase is AppStorePurchaseDetails` similarly to the existing GooglePlay branch.

### iOS-specific build config

- `flutter pub get` then `cd ios && pod install` (auto-includes StoreKit pods via `in_app_purchase_storekit` 0.4.7, transitively pulled by `in_app_purchase: ^3.2.3`)
- No Info.plist changes needed for IAP itself
- No new explicit dependency on `in_app_purchase_storekit` is required (it's already resolved via the federated plugin)

## Test Strategy

### Unit Tests

- pgTAP tests for schema and seed data (covered above in DB Changes)
- Edge Function logic that does not depend on real Apple signatures can be exercised with `supabase functions serve` + `curl` posting fabricated bodies. JWS verification will reject all such attempts (correctly), so testing focuses on input parsing, error paths, and the always-200 contract.

### End-to-End on Sandbox

Run on a real iOS device signed in with a Sandbox tester (Settings → App Store → Sandbox Account):

**A. New purchase**
1. App → Wallet → Choose Plan → Light → buy → Apple UI → confirm
2. Verify in Edge Function logs: `notificationType: SUBSCRIBED`
3. Verify DB: new row in `user_subscriptions` (provider=apple, status=active, plan_id=light, apple_original_transaction_id set)
4. Verify `point_ledger`: +5 with `invoice_id = apple:{transactionId}`
5. Verify `trial_point_wallets.is_active = false` for that user
6. Verify Flutter UI flips to "ライトプラン契約中" (via progressive polling)

**B. Auto-renewal (5 minutes after A)**
1. Wait 5 minutes (Sandbox monthly renewal cadence)
2. Verify `notificationType: DID_RENEW`
3. Verify `current_period_end` advances
4. Verify `point_ledger`: another +5 with a new `invoice_id` (different transactionId)

**C. Upgrade (Light → Premium)**
1. From state A, choose Premium → buy
2. Apple handles in-group upgrade with prorated billing
3. Verify `user_subscriptions.plan_id` becomes `premium`
4. Verify `point_ledger`: +20 (idempotency holds — no double-spend)

**D. Downgrade (Premium → Light)**
1. From state C, choose Light → buy
2. Apple defers downgrade until period end — `plan_id` stays `premium` for now
3. Wait until period end → DID_RENEW → `plan_id` becomes `light`

**E. Cancellation**
1. From state A, iOS Settings → Subscriptions → cancel
2. Verify `notificationType: DID_CHANGE_RENEWAL_STATUS` with subtype `AUTO_RENEW_DISABLED`
3. Verify `cancel_at_period_end = true`
4. Verify the app remains usable until period end

**F. Expiry (after E)**
1. Wait 5 minutes for the Sandbox period to end
2. Verify `notificationType: EXPIRED`
3. Verify `status = canceled`

**G. Restore Purchases**
1. Reinstall app, log in, observe subscription state restored automatically (via `subscriptionProvider`)
2. Profile → Restore Purchases → SnackBar "購入を復元しました"
3. Verify `subscriptionProvider` reflects the active subscription

### TestFlight Internal Testing

After Sandbox passes, distribute to TestFlight Internal Testing (no App Review needed for internal). TestFlight builds run automatically against the Sandbox environment. Re-run scenarios A–G in this near-production setup.

### Regression Testing

- Android: re-run equivalent A–F flows on a physical Android device with a Google account distinct from the Apple Sandbox tester. Ensure existing Google Play behavior is unchanged.
- Stripe (webapp): no code change, but smoke-check that webhook processing still works (no inadvertent regression in shared point/ledger logic).

### Local Development Limits

- Local-only end-to-end is not possible — Apple cannot deliver ASSN to localhost. Use ngrok or staging Supabase as the Sandbox endpoint.
- Local runs are useful only for Flutter unit tests and Edge Function single-request shape testing.

## Risks and Open Items

### R1. Staging Supabase environment readiness

The design assumes a staging Supabase project exists where the Sandbox ASSN URL points. If the staging project is not fully provisioned (DB migrations in sync, secrets set, function deployable), a separate prep task will be needed before scenario testing. Implementation of the DB migration / Edge Function / Flutter changes can proceed in parallel; only the verification phase needs the staging environment ready.

### R2. `applicationUserName` → `appAccountToken` propagation

`in_app_purchase_storekit` 0.4.7 is expected to pass `applicationUserName` as Apple's `appAccountToken`. If real Sandbox tests show the field arriving empty or non-UUID, a Method Channel + Swift fallback is the contingency: native code calls `Product.purchase(options: [.appAccountToken(uuid)])` directly.

### R3. `app-store-server-library` on Deno

The Apple official npm SDK targets Node. Deno's `npm:` specifier should handle most cases, but Node-only API usage (e.g. `crypto` differences) may surface. Fallback: `jose` for the JWS verification and a hand-rolled X.509 chain validator pinned to Apple Root CA. Decided after a smoke test in the function runtime.

### R4. Apple's "first subscription must ship with a new app version" rule

Initial subscription products must be submitted to App Review together with a new app binary. This is irrelevant for Sandbox testing (which just requires "Ready to Submit"-grade metadata) but matters for the eventual production submission, which is out of scope here.

### R5. TestFlight Internal Testing constraints

Internal Testing supports up to 100 users and only people in the App Store Connect team. Sufficient for a solo-operated app.

## Out of Scope

- Sign In with Apple (production review blocker; tracked in #413)
- Production App Store submission (screenshots, review notes, age rating, legal URL registration, Review Screenshots per IAP product)
- Promotional / Introductory Offers (free trials are covered by trial points)
- Family Sharing for subscriptions
- Pricing in non-JPY currencies
- Stripe IAP path on iOS (already deferred per `2026-04-09-subscription-iap-only-design.md`)

## Recommended Implementation Order

1. **DB migration** (this design's DB Changes section) including #411 Google price alignment
2. **Edge Function** `handle-app-store-server-notification`, deployed to staging first
3. **App Store Connect**: set Sandbox URL, send test notification → confirm Edge Function receives it
4. **Flutter changes**: cancel-link platform branching, Restore Purchases link in SupportSection
5. **Sandbox tester creation + scenarios A–G** (in parallel: confirm staging Supabase environment is fully ready; address gaps if found)
6. **TestFlight Internal Testing** rerun of A–G
7. **Regression check** on Android

## Acceptance Criteria

- Scenarios A–G pass on staging + real iOS device with Sandbox tester
- Scenarios A–G pass via TestFlight Internal Testing
- Android Google Play IAP flows show no regression
- Edge Function logs are clean (no unexpected exceptions)
- Issue #402 checklist items all marked complete:
  - Apple Developer Program enrollment (Sole Entrepreneur, identity verified)
  - App registered in App Store Connect with bundle ID `dev.cloveclove.peppercheck`
  - In-App Purchase capability enabled
- Issue #411 closeable: Apple/Google premium prices both at ¥2,480

## Related Issues

- [#402](https://github.com/cloveclovedev/peppercheck/issues/402) — this design's parent
- [#411](https://github.com/cloveclovedev/peppercheck/issues/411) — Apple/Google price alignment (resolved by this design's DB migration + Play Console price change)
- [#413](https://github.com/cloveclovedev/peppercheck/issues/413) — Sign In with Apple (separate, but a hard blocker for production)

## References

- `docs/superpowers/specs/2026-03-30-google-play-iap-design.md` — Android counterpart, mirrored architecture
- `docs/superpowers/specs/2026-04-09-subscription-iap-only-design.md` — IAP-only policy
- `supabase/functions/handle-google-play-rtdn/index.ts` — reference implementation pattern
- [Apple — App Store Server Notifications V2](https://developer.apple.com/documentation/appstoreservernotifications/app_store_server_notifications_v2)
- [Apple — app-store-server-library (Node)](https://github.com/apple/app-store-server-library-node)
- [Apple App Review Guideline 3.1.1 — Restore Purchases requirement](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)
- [Apple App Review Guideline 4.8 — Sign in with Apple requirement](https://developer.apple.com/app-store/review/guidelines/#login-services)
