# Google Play IAP Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Google Play In-App Purchase subscriptions with RTDN-based lifecycle management, mirroring the existing Stripe webhook pattern.

**Architecture:** A single `handle-google-play-rtdn` Edge Function receives all Google Play subscription lifecycle events via Cloud Pub/Sub push. User identification uses `externalAccountIdentifiers` from the subscriptionsv2.get API. Flutter's purchase flow calls `completePurchase()` then waits for Supabase Realtime to detect the DB update from RTDN. `verify-google-purchase` is deleted.

**Tech Stack:** Supabase Edge Functions (Deno/TypeScript), Flutter (Dart, in_app_purchase, Riverpod), Google Play Developer API v3 (subscriptionsv2), Cloud Pub/Sub, jose (JWT/OIDC)

**Prerequisite (manual):** Complete Google Play Console setup (subscription products, service account, Pub/Sub topic, RTDN configuration) as documented in `docs/superpowers/specs/2026-03-30-google-play-iap-design.md` § "Google Play Console Setup".

**Note:** The "Manage Subscription" button linking to the web dashboard is kept for now. If Google Play review flags it as an external purchase path, replace the URL with `https://play.google.com/store/account/subscriptions?package=dev.cloveclove.peppercheck`.

---

### Task 1: Scaffold `handle-google-play-rtdn` Edge Function

**Files:**
- Create: `supabase/functions/handle-google-play-rtdn/index.ts` (via CLI)
- Create: `supabase/functions/handle-google-play-rtdn/deno.json` (via CLI, then edit)
- Modify: `supabase/config.toml:614`

- [ ] **Step 1: Generate Edge Function boilerplate**

Run:
```bash
cd /Users/makoto/projects/peppercheck && supabase functions new handle-google-play-rtdn
```

- [ ] **Step 2: Update `deno.json` with dependencies**

Replace the generated `supabase/functions/handle-google-play-rtdn/deno.json`:

```json
{
  "imports": {
    "jose": "npm:jose@^6",
    "@supabase/supabase-js": "jsr:@supabase/supabase-js@2"
  }
}
```

- [ ] **Step 3: Add Edge Function config to `config.toml`**

Add after the `[functions.handle-stripe-webhook]` section (after line 614):

```toml
[functions.handle-google-play-rtdn]
enabled = true
verify_jwt = false
import_map = "./functions/handle-google-play-rtdn/deno.json"
entrypoint = "./functions/handle-google-play-rtdn/index.ts"
```

- [ ] **Step 4: Write minimal handler skeleton**

Replace `supabase/functions/handle-google-play-rtdn/index.ts`:

```typescript
import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from '@supabase/supabase-js'

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const body = await req.json()
    console.log('Received Pub/Sub message:', JSON.stringify(body))
    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing RTDN:', error)
    // Always return 200 to prevent Pub/Sub infinite retries
    return new Response(JSON.stringify({ error: 'processing failed' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  }
})
```

- [ ] **Step 5: Verify Edge Function compiles**

Run:
```bash
cd /Users/makoto/projects/peppercheck && supabase functions serve handle-google-play-rtdn --no-verify-jwt 2>&1 | head -5
```

Expected: Function starts serving without compilation errors. Stop with Ctrl+C after confirming.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/handle-google-play-rtdn/ supabase/config.toml
git commit -m "feat(edge-functions): scaffold handle-google-play-rtdn Edge Function"
```

---

### Task 2: Implement OIDC verification and Google API auth

**Files:**
- Modify: `supabase/functions/handle-google-play-rtdn/index.ts`

- [ ] **Step 1: Add OIDC verification function**

Add after the import statements in `index.ts`:

```typescript
import { createRemoteJWKSet, jwtVerify, importPKCS8, SignJWT } from 'jose'

const GOOGLE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
)

async function verifyPubSubOidcToken(req: Request): Promise<boolean> {
  const expectedAudience = Deno.env.get('GOOGLE_PUBSUB_AUDIENCE')
  const expectedEmail = Deno.env.get('GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL')

  if (!expectedAudience || !expectedEmail) {
    console.error('Missing GOOGLE_PUBSUB_AUDIENCE or GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL env vars')
    return false
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) return false

  const token = authHeader.slice(7)

  try {
    const { payload } = await jwtVerify(token, GOOGLE_JWKS, {
      audience: expectedAudience,
      issuer: 'https://accounts.google.com',
    })

    if (!payload.email_verified) return false
    if (payload.email !== expectedEmail) return false

    return true
  } catch (err) {
    console.error('OIDC token verification failed:', err)
    return false
  }
}
```

- [ ] **Step 2: Add Google API auth function**

Add after `verifyPubSubOidcToken` in `index.ts`. This is extracted from `verify-google-purchase/index.ts`:

```typescript
async function getGoogleAccessToken(
  credentials: { client_email: string; private_key: string },
  scope: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const privateKey = await importPKCS8(credentials.private_key, 'RS256')

  const jwt = await new SignJWT({
    iss: credentials.client_email,
    scope,
    aud: 'https://oauth2.googleapis.com/token',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!res.ok) {
    const body = await res.text()
    throw new Error(`Google token exchange failed (${res.status}): ${body}`)
  }

  const data = await res.json()
  return data.access_token
}
```

- [ ] **Step 3: Add subscriptionsv2.get function**

Add after `getGoogleAccessToken`:

```typescript
const PACKAGE_NAME = 'dev.cloveclove.peppercheck'

interface SubscriptionV2 {
  subscriptionState: string
  startTime?: string
  lineItems?: Array<{
    productId: string
    expiryTime: string
    autoRenewingPlan?: Record<string, unknown>
  }>
  externalAccountIdentifiers?: {
    obfuscatedExternalAccountId?: string
    obfuscatedExternalProfileId?: string
  }
  acknowledgementState?: string
}

async function fetchSubscriptionV2(purchaseToken: string): Promise<SubscriptionV2> {
  const serviceAccountJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
  if (!serviceAccountJson) throw new Error('Missing GOOGLE_SERVICE_ACCOUNT_JSON')

  const credentials = JSON.parse(serviceAccountJson)
  const accessToken = await getGoogleAccessToken(
    credentials,
    'https://www.googleapis.com/auth/androidpublisher',
  )

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${purchaseToken}`

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  if (!res.ok) {
    const body = await res.text()
    throw new Error(`subscriptionsv2.get failed (${res.status}): ${body}`)
  }

  return res.json()
}
```

- [ ] **Step 4: Wire OIDC verification into the handler**

Update the `Deno.serve` handler to verify OIDC before processing:

```typescript
Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Verify OIDC token from Pub/Sub
  const isAuthentic = await verifyPubSubOidcToken(req)
  if (!isAuthentic) {
    console.error('OIDC verification failed, rejecting request')
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    const body = await req.json()
    console.log('Received authenticated Pub/Sub message:', JSON.stringify(body))
    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing RTDN:', error)
    return new Response(JSON.stringify({ error: 'processing failed' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  }
})
```

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/handle-google-play-rtdn/index.ts
git commit -m "feat(edge-functions): add OIDC verification and Google API auth to RTDN handler"
```

---

### Task 3: Implement RTDN notification handling

**Files:**
- Modify: `supabase/functions/handle-google-play-rtdn/index.ts`

- [ ] **Step 1: Add notification type constants and helper functions**

Add after the `SubscriptionV2` interface:

```typescript
// RTDN notification types
// https://developer.android.com/google/play/billing/rtdn-reference
const NOTIFICATION_TYPE = {
  RECOVERED: 1,
  RENEWED: 2,
  CANCELED: 3,
  PURCHASED: 4,
  ON_HOLD: 5,
  IN_GRACE_PERIOD: 6,
  RESTARTED: 7,
  PRICE_CHANGE_CONFIRMED: 8,
  DEFERRED: 9,
  PAUSED: 10,
  PAUSE_SCHEDULE_CHANGED: 11,
  REVOKED: 12,
  EXPIRED: 13,
} as const

// Google Play product IDs are '{planId}_monthly', DB plan IDs are '{planId}'
function extractPlanId(productId: string): string {
  return productId.replace('_monthly', '')
}

// Map notification types to subscription_status enum values in DB
function mapSubscriptionStatus(notificationType: number): string | null {
  switch (notificationType) {
    case NOTIFICATION_TYPE.PURCHASED:
    case NOTIFICATION_TYPE.RENEWED:
    case NOTIFICATION_TYPE.RECOVERED:
    case NOTIFICATION_TYPE.RESTARTED:
      return 'active'
    case NOTIFICATION_TYPE.IN_GRACE_PERIOD:
      return 'past_due'
    case NOTIFICATION_TYPE.ON_HOLD:
      return 'unpaid'
    case NOTIFICATION_TYPE.CANCELED:
    case NOTIFICATION_TYPE.EXPIRED:
    case NOTIFICATION_TYPE.REVOKED:
      return 'canceled'
    case NOTIFICATION_TYPE.PAUSED:
      return 'paused'
    default:
      return null
  }
}
```

- [ ] **Step 2: Add subscription notification handler**

Add after `mapSubscriptionStatus`:

```typescript
async function handleSubscriptionNotification(
  notificationType: number,
  purchaseToken: string,
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<void> {
  // Always fetch current state — notifications are signals, not data
  const subscription = await fetchSubscriptionV2(purchaseToken)

  const userId = subscription.externalAccountIdentifiers?.obfuscatedExternalAccountId
  if (!userId) {
    console.error('No obfuscatedExternalAccountId found in subscription response')
    return
  }

  const lineItem = subscription.lineItems?.[0]
  if (!lineItem) {
    console.error('No line items in subscription response')
    return
  }

  const planId = extractPlanId(lineItem.productId)
  const status = mapSubscriptionStatus(notificationType)

  if (!status) {
    console.log(`Notification type ${notificationType} does not require status update, skipping`)
    return
  }

  console.log(`Processing notification type=${notificationType} for user=${userId} plan=${planId} status=${status}`)

  // Handle CANCELED: only update cancel_at_period_end, keep status active until expiry
  if (notificationType === NOTIFICATION_TYPE.CANCELED) {
    const { error } = await supabaseAdmin
      .from('user_subscriptions')
      .update({
        cancel_at_period_end: true,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)

    if (error) {
      console.error('Failed to update cancel_at_period_end:', error)
      throw error
    }
    console.log(`Marked cancel_at_period_end for user ${userId}`)
    return
  }

  // Upsert subscription for all other notification types
  const { error: upsertError } = await (supabaseAdmin.from('user_subscriptions') as any).upsert({
    user_id: userId,
    plan_id: planId,
    status: status,
    provider: 'google',
    google_purchase_token: purchaseToken,
    current_period_start: subscription.startTime
      ? new Date(subscription.startTime).toISOString()
      : new Date().toISOString(),
    current_period_end: new Date(lineItem.expiryTime).toISOString(),
    cancel_at_period_end: !lineItem.autoRenewingPlan,
    updated_at: new Date().toISOString(),
  })

  if (upsertError) {
    console.error('Failed to upsert user_subscription:', upsertError)
    throw upsertError
  }

  // Grant points on PURCHASED or RENEWED
  if (
    notificationType === NOTIFICATION_TYPE.PURCHASED ||
    notificationType === NOTIFICATION_TYPE.RENEWED
  ) {
    const { data: planData, error: planError } = await (supabaseAdmin
      .from('subscription_plans') as any)
      .select('monthly_points')
      .eq('id', planId)
      .single()

    if (planError || !planData) {
      console.error(`Failed to fetch plan data for ${planId}:`, planError?.message)
      throw new Error(`Plan not found: ${planId}`)
    }

    if (planData.monthly_points > 0) {
      // Idempotency key: google:{purchaseToken}:{expiryTime}
      // Using expiryTime ensures each renewal period gets a unique key
      // (purchaseToken stays the same for the life of the subscription)
      const invoiceId = `google:${purchaseToken}:${lineItem.expiryTime}`
      const { data: granted, error: rpcError } = await supabaseAdmin.rpc(
        'grant_subscription_points',
        {
          p_user_id: userId,
          p_amount: planData.monthly_points,
          p_invoice_id: invoiceId,
        },
      )

      if (rpcError) {
        console.error(`grant_subscription_points failed:`, rpcError)
        throw rpcError
      }

      if (granted) {
        console.log(`Granted ${planData.monthly_points} points to user ${userId}`)
      } else {
        console.log(`Points already granted for ${invoiceId}, skipping (idempotent)`)
      }
    }
  }

  // Deactivate trial points on PURCHASED (best-effort)
  if (notificationType === NOTIFICATION_TYPE.PURCHASED) {
    const { error: trialError } = await supabaseAdmin.rpc('deactivate_trial_points', {
      p_user_id: userId,
    })
    if (trialError) {
      console.error(`Failed to deactivate trial points for user ${userId}:`, trialError)
      // Don't throw — subscription activation is primary
    } else {
      console.log(`Trial points deactivated for user ${userId}`)
    }
  }
}
```

- [ ] **Step 3: Update the main handler to parse Pub/Sub envelope and route**

Replace the `Deno.serve` handler:

```typescript
Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Verify OIDC token from Pub/Sub
  const isAuthentic = await verifyPubSubOidcToken(req)
  if (!isAuthentic) {
    console.error('OIDC verification failed, rejecting request')
    return new Response('Unauthorized', { status: 401 })
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  try {
    const body = await req.json()

    // Parse Pub/Sub push envelope
    const messageData = body.message?.data
    if (!messageData) {
      console.error('No message.data in Pub/Sub envelope')
      return new Response(JSON.stringify({ received: true }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Decode base64 notification data
    const decoded = atob(messageData)
    const notification = JSON.parse(decoded)

    console.log(`RTDN: package=${notification.packageName}, event_time=${notification.eventTimeMillis}`)

    // Handle test notification
    if (notification.testNotification) {
      console.log('Received test notification, version:', notification.testNotification.version)
      return new Response(JSON.stringify({ received: true, test: true }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Handle subscription notification
    if (notification.subscriptionNotification) {
      const { notificationType, purchaseToken } = notification.subscriptionNotification
      console.log(`Subscription notification: type=${notificationType}, token=${purchaseToken}`)

      await handleSubscriptionNotification(notificationType, purchaseToken, supabaseAdmin)
    } else {
      console.log('Received non-subscription notification, skipping')
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing RTDN:', error)
    // Always return 200 to prevent Pub/Sub infinite retries
    return new Response(JSON.stringify({ error: 'processing failed' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  }
})
```

- [ ] **Step 4: Verify the function compiles**

Run:
```bash
cd /Users/makoto/projects/peppercheck && supabase functions serve handle-google-play-rtdn --no-verify-jwt 2>&1 | head -5
```

Expected: Function starts serving. Stop with Ctrl+C.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/handle-google-play-rtdn/index.ts
git commit -m "feat(edge-functions): implement RTDN notification handling with lifecycle management"
```

---

### Task 4: Enable Supabase Realtime on `user_subscriptions`

Flutter will subscribe to Realtime changes on `user_subscriptions` to detect when RTDN updates the subscription status after a purchase.

**Files:**
- Create: `supabase/schemas/subscription/tables/realtime.sql`
- Modify: `supabase/config.toml` (schema file list)
- Create: new migration via `supabase db diff`

- [ ] **Step 1: Create a schema file for Realtime publication**

Create `supabase/schemas/subscription/tables/realtime.sql`:

```sql
-- Enable Realtime for user_subscriptions so Flutter clients can detect
-- subscription status changes from RTDN processing
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions;
```

- [ ] **Step 2: Register the schema file in `config.toml`**

In `supabase/config.toml`, find the `[db.migrations]` schema file list and add:

```
"./schemas/subscription/tables/realtime.sql"
```

Add it after the existing subscription schema entries.

- [ ] **Step 3: Generate migration**

Run:
```bash
cd /Users/makoto/projects/peppercheck && supabase db diff -f enable_realtime_user_subscriptions
```

Review the generated migration file. If `ALTER PUBLICATION` is not captured by `db diff`, manually append to the migration file:

```sql
-- DML, not detected by schema diff
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions;
```

- [ ] **Step 4: Reset and verify**

Run:
```bash
cd /Users/makoto/projects/peppercheck && ./scripts/db-reset-and-clear-android-emulators-cache.sh
```

Expected: All migrations apply successfully.

- [ ] **Step 5: Run regression tests**

Run:
```bash
for f in supabase/tests/test_*.sql; do
  echo "=== Running $f ==="
  docker cp "$f" supabase_db_supabase:/tmp/ && \
  docker exec supabase_db_supabase psql -U postgres -f "/tmp/$(basename "$f")"
  echo ""
done
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add supabase/schemas/subscription/tables/realtime.sql supabase/migrations/ supabase/config.toml
git commit -m "feat(supabase): enable Realtime on user_subscriptions for IAP purchase detection"
```

---

### Task 5: Flutter — Update purchase flow

**Files:**
- Modify: `peppercheck_flutter/lib/features/billing/data/in_app_purchase_repository.dart`
- Modify: `peppercheck_flutter/lib/features/billing/presentation/in_app_purchase_controller.dart`

- [ ] **Step 1: Add `in_app_purchase_android` dependency**

Run:
```bash
cd /Users/makoto/projects/peppercheck/peppercheck_flutter && flutter pub add in_app_purchase_android
```

This is needed for `GooglePlayPurchaseParam`, `GooglePlayPurchaseDetails`, and `ChangeSubscriptionParam` types.

- [ ] **Step 2: Rewrite `InAppPurchaseRepository`**

Replace `peppercheck_flutter/lib/features/billing/data/in_app_purchase_repository.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'in_app_purchase_repository.g.dart';

@Riverpod(keepAlive: true)
InAppPurchaseRepository inAppPurchaseRepository(Ref ref) {
  return InAppPurchaseRepository(InAppPurchase.instance);
}

class InAppPurchaseRepository {
  final InAppPurchase _iap;
  final _logger = Logger();

  InAppPurchaseRepository(this._iap);

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<void> buySubscription({
    required ProductDetails product,
    required String userId,
    GooglePlayPurchaseDetails? oldPurchase,
    bool isUpgrade = false,
  }) async {
    late PurchaseParam purchaseParam;

    if (Platform.isAndroid && oldPurchase != null) {
      // Upgrade or downgrade: use GooglePlayPurchaseParam with change info
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: userId,
        changeSubscriptionParam: ChangeSubscriptionParam(
          oldPurchaseDetails: oldPurchase,
          replacementMode: isUpgrade
              ? ReplacementMode.chargeProrationPrice
              : ReplacementMode.deferred,
        ),
      );
    } else {
      purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: userId,
      );
    }

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
    await _iap.completePurchase(purchase);
  }

  Future<List<ProductDetails>> fetchProducts(Set<String> productIds) async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.notFoundIDs.isNotEmpty) {
      _logger.w('Products not found: ${response.notFoundIDs}');
    }
    if (response.error != null) {
      throw response.error!;
    }
    return response.productDetails;
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
```

- [ ] **Step 3: Rewrite `InAppPurchaseController`**

Replace `peppercheck_flutter/lib/features/billing/presentation/in_app_purchase_controller.dart`:

```dart
import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/data/in_app_purchase_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'in_app_purchase_controller.g.dart';

@riverpod
Future<List<ProductDetails>> availableProducts(Ref ref) async {
  const productIds = <String>{
    'light_monthly',
    'standard_monthly',
    'premium_monthly',
  };

  final repo = ref.watch(inAppPurchaseRepositoryProvider);
  if (!await repo.isAvailable()) {
    return [];
  }
  return repo.fetchProducts(productIds);
}

@Riverpod(keepAlive: true)
class InAppPurchaseController extends _$InAppPurchaseController {
  final _logger = Logger();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  RealtimeChannel? _realtimeChannel;

  @override
  FutureOr<void> build() {
    final repo = ref.watch(inAppPurchaseRepositoryProvider);
    _purchaseSubscription = repo.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () {
        _purchaseSubscription?.cancel();
      },
      onError: (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );

    ref.onDispose(() {
      _purchaseSubscription?.cancel();
      _removeRealtimeSubscription();
    });
  }

  Future<void> buy({
    required ProductDetails product,
    GooglePlayPurchaseDetails? oldPurchase,
    bool isUpgrade = false,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await repo.buySubscription(
        product: product,
        userId: userId,
        oldPurchase: oldPurchase,
        isUpgrade: isUpgrade,
      );
      // Result arrives via purchaseStream
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> restorePurchases() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      await repo.restorePurchases();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    final repo = ref.read(inAppPurchaseRepositoryProvider);

    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        state = const AsyncLoading();
      } else if (purchase.status == PurchaseStatus.error) {
        _logger.e('Purchase Error: ${purchase.error}');
        state = AsyncError(purchase.error!, StackTrace.current);
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          // Acknowledge the purchase with Google Play
          if (purchase.pendingCompletePurchase) {
            await repo.completePurchase(purchase);
          }

          // Subscribe to Realtime to detect when RTDN updates the DB
          _subscribeToRealtimeUpdates();

          // State remains loading until Realtime detects the subscription change
        } catch (e, st) {
          _logger.e('Purchase completion failed', error: e, stackTrace: st);
          state = AsyncError(e, st);
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        state = const AsyncData(null);
      }
    }
  }

  void _subscribeToRealtimeUpdates() {
    _removeRealtimeSubscription();

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('iap-subscription-status')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _logger.i('Subscription updated via Realtime: ${payload.newRecord}');
            ref.invalidate(subscriptionProvider);
            ref.invalidate(pointWalletProvider);
            state = const AsyncData(null);
            _removeRealtimeSubscription();
          },
        )
        .subscribe();
  }

  void _removeRealtimeSubscription() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }
}
```

- [ ] **Step 4: Run code generation**

Run:
```bash
cd /Users/makoto/projects/peppercheck/peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
```

Expected: Code generation completes successfully.

- [ ] **Step 5: Verify the app compiles**

Run:
```bash
cd /Users/makoto/projects/peppercheck/peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
cd /Users/makoto/projects/peppercheck
git add peppercheck_flutter/lib/features/billing/data/in_app_purchase_repository.dart
git add peppercheck_flutter/lib/features/billing/data/in_app_purchase_repository.g.dart
git add peppercheck_flutter/lib/features/billing/presentation/in_app_purchase_controller.dart
git add peppercheck_flutter/lib/features/billing/presentation/in_app_purchase_controller.g.dart
git add peppercheck_flutter/pubspec.yaml peppercheck_flutter/pubspec.lock
git commit -m "feat(flutter): update IAP purchase flow for RTDN-based processing"
```

---

### Task 6: Flutter — Enable product list and purchase UI

**Files:**
- Modify: `peppercheck_flutter/lib/features/billing/presentation/widgets/subscription_section.dart`
- Modify: Translation source files under `peppercheck_flutter/lib/gen/slang/`

- [ ] **Step 1: Add `processingPurchase` translation key**

Find the translation source files (e.g., `peppercheck_flutter/lib/i18n/` or slang YAML/JSON files). Add under the `billing` section:

```
processingPurchase: サブスクリプションを処理中...
```

Run slang code generation:
```bash
cd /Users/makoto/projects/peppercheck/peppercheck_flutter && dart run slang 2>&1 | tail -5
```

- [ ] **Step 2: Rewrite `subscription_section.dart`**

Replace `peppercheck_flutter/lib/features/billing/presentation/widgets/subscription_section.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/presentation/in_app_purchase_controller.dart';
import 'package:peppercheck_flutter/app/utils/date_time_utils.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionSection extends ConsumerWidget {
  const SubscriptionSection({super.key});

  Future<void> _launchWebDashboard() async {
    final baseUrl =
        dotenv.env['WEB_DASHBOARD_URL'] ?? 'http://localhost:3000/dashboard';
    final url = Uri.parse(baseUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  String _getPlanName(String? planId) {
    if (planId == 'light') return t.billing.plans.light;
    if (planId == 'standard') return t.billing.plans.standard;
    if (planId == 'premium') return t.billing.plans.premium;
    return t.billing.noPlan;
  }

  Color _getPlanColor(String? planId) {
    if (planId == 'light') return AppColors.accentGreen;
    if (planId == 'standard') return AppColors.accentBlue;
    if (planId == 'premium') return AppColors.accentYellow;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final purchaseState = ref.watch(inAppPurchaseControllerProvider);

    final isPurchasing = purchaseState.isLoading;

    return Stack(
      children: [
        BaseSection(
          title: t.billing.subscription,
          child: state.when(
            data: (subscription) {
              final status = subscription?.status;
              final planId = subscription?.planId;
              final expiry = subscription?.currentPeriodEnd;
              final bool isActive = status == 'active';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacingMedium,
                      vertical: AppSizes.spacingSmall,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: _getPlanColor(planId),
                          size: 32,
                        ),
                        const SizedBox(width: AppSizes.spacingMedium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getPlanName(planId),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if ((status != null && !isActive) ||
                                  expiry != null) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    if (status != null && !isActive)
                                      Text(
                                        status,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (expiry != null)
                                      Text(
                                        '${t.billing.renews}: ${formatDate(DateTime.parse(expiry).toLocal())}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingSmall),

                  if (!isActive) ...[
                    const _ProductList(),
                    const SizedBox(height: AppSizes.spacingSmall),
                  ],

                  ActionButton(
                    text: t.billing.manageSubscription,
                    icon: Icons.open_in_new,
                    onPressed: _launchWebDashboard,
                  ),

                  if (purchaseState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Purchase Error: ${purchaseState.error}',
                        style: const TextStyle(color: AppColors.textError),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text(
              'Error: $e',
              style: const TextStyle(color: AppColors.textError),
            ),
          ),
        ),
        if (isPurchasing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSizes.spacingMedium),
                    Text(
                      t.billing.processingPurchase,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(availableProductsProvider);

    return productsState.when(
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort by price ascending (light < standard < premium)
        final sorted = List<ProductDetails>.from(products)
          ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sorted.map((product) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacingSmall),
              child: _ProductCard(product: product),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductDetails product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(AppSizes.spacingMedium),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
      ),
      onPressed: () {
        ref
            .read(inAppPurchaseControllerProvider.notifier)
            .buy(product: product);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              product.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            product.price,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.accentBlue,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify the app compiles**

Run:
```bash
cd /Users/makoto/projects/peppercheck/peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
cd /Users/makoto/projects/peppercheck
git add peppercheck_flutter/lib/features/billing/presentation/widgets/subscription_section.dart
git add peppercheck_flutter/lib/gen/slang/
git add peppercheck_flutter/lib/i18n/
git commit -m "feat(flutter): enable product list UI and purchase buttons for Google Play IAP"
```

---

### Task 7: Delete `verify-google-purchase`

**Files:**
- Delete: `supabase/functions/verify-google-purchase/` (entire directory)
- Modify: `supabase/config.toml:616-625`

- [ ] **Step 1: Delete the deployed Edge Function**

Run:
```bash
cd /Users/makoto/projects/peppercheck && supabase functions delete verify-google-purchase
```

Expected: Function deleted from remote Supabase project.

- [ ] **Step 2: Remove config from `config.toml`**

In `supabase/config.toml`, delete the entire `[functions.verify-google-purchase]` section (lines 616-625):

```toml
[functions.verify-google-purchase]
enabled = true
verify_jwt = true
import_map = "./functions/verify-google-purchase/deno.json"
# Uncomment to specify a custom file path to the entrypoint.
# Supported file extensions are: .ts, .js, .mjs, .jsx, .tsx
entrypoint = "./functions/verify-google-purchase/index.ts"
# Specifies static files to be bundled with the function. Supports glob patterns.
# For example, if you want to serve static HTML pages in your function:
# static_files = [ "./functions/verify-google-purchase/*.html" ]
```

- [ ] **Step 3: Delete local function directory**

Run:
```bash
rm -rf /Users/makoto/projects/peppercheck/supabase/functions/verify-google-purchase
```

- [ ] **Step 4: Commit**

```bash
cd /Users/makoto/projects/peppercheck
git add -A supabase/functions/verify-google-purchase/ supabase/config.toml
git commit -m "chore(edge-functions): delete verify-google-purchase in favor of RTDN handler"
```

---

### Task 8: Deploy and manual integration testing

This task requires Google Play Console setup to be completed first (see design spec).

- [ ] **Step 1: Deploy the Edge Function**

Run:
```bash
cd /Users/makoto/projects/peppercheck && supabase functions deploy handle-google-play-rtdn
```

- [ ] **Step 2: Set environment variables**

Run:
```bash
supabase secrets set GOOGLE_PUBSUB_AUDIENCE="https://<project-ref>.supabase.co/functions/v1/handle-google-play-rtdn"
supabase secrets set GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL="<push-subscription-sa>@<gcp-project>.iam.gserviceaccount.com"
```

Verify `GOOGLE_SERVICE_ACCOUNT_JSON` is already set:
```bash
supabase secrets list | grep GOOGLE_SERVICE_ACCOUNT_JSON
```

- [ ] **Step 3: Verify RTDN test notification**

In Play Console > Monetize > Monetization setup > Real-time developer notifications, click "Send test notification."

Check Edge Function logs:
```bash
supabase functions logs handle-google-play-rtdn --tail
```

Expected: Log line containing `Received test notification, version:`.

- [ ] **Step 4: Add license tester accounts**

In Play Console > Setup > License testing, add tester Google accounts.

- [ ] **Step 5: Test full purchase lifecycle**

Install the debug APK on a device signed in with a license tester account. Test:

1. **New purchase**: Purchase → RTDN `PURCHASED` → subscription active → points granted → trial points deactivated
2. **Renewal**: Wait 5 min for auto-renewal → RTDN `RENEWED` → additional points granted (verify idempotency)
3. **Cancellation**: Cancel from Play Store → RTDN `CANCELED` → `cancel_at_period_end = true`
4. **Expiry**: After cancellation + expiry → RTDN `EXPIRED` → status changes to canceled
5. **Upgrade/downgrade**: light → standard → verify correct plan switch
6. **Restore**: Reinstall app → `restorePurchases()` → subscription state restored

- [ ] **Step 6: Commit any fixes from testing**

```bash
git add -A
git commit -m "fix(edge-functions): address issues found during IAP integration testing"
```
