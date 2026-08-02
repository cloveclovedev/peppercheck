# iOS In-App Purchase Subscription Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror the Google Play IAP integration on iOS so subscription purchases on iOS builds are processed via Apple StoreKit and App Store Server Notifications V2 (ASSN V2), with a single backend handler that consumes the JWS-signed notification payload directly.

**Architecture:** A new Supabase Edge Function `handle-app-store-server-notification` receives ASSN V2 over HTTPS, verifies the JWS chain via `@apple/app-store-server-library`, decodes the nested `signedTransactionInfo` / `signedRenewalInfo`, identifies the user via `transactionInfo.appAccountToken` (set by the Flutter client as `applicationUserName`), upserts `user_subscriptions`, and reuses the existing RPCs `reset_subscription_points` and `deactivate_trial_points`. DB gains an `apple_original_transaction_id` column on `user_subscriptions` and Apple-provider rows in `subscription_plan_prices` (¥650 / ¥1,280 / ¥2,480). Flutter gains an iOS-branched cancel link and an iOS-only "Restore Purchases" tile in `SupportSection`. Subscription state refresh after purchase reuses the existing `[1, 1, 2, 2, 3]`-second progressive polling loop in `InAppPurchaseController._scheduleSubscriptionRefresh()` — **no Supabase Realtime**.

**Tech Stack:** Supabase Edge Functions (Deno), `@apple/app-store-server-library` (npm), PostgreSQL (pgTAP tests), Flutter (Riverpod, slang i18n, `in_app_purchase` 3.x).

> **Spec deviation note:** The design doc states Apple Root CA certs are bundled with `app-store-server-library`. They are not — per the SDK README, callers must supply `Buffer[]` of root certs. This plan ships `AppleRootCA-G2.cer`, `AppleRootCA-G3.cer`, and `AppleComputerRootCertificate.cer` as `static_files` of the Edge Function. These are public Apple root certificates (the same ones every OS ships in its trust store), so committing them to git is appropriate.

> **Test scope:** Pure helpers (`extractPlanId`, `mapNotificationToStatus`) get Deno unit tests. The handler itself is not unit-tested — JWS verification cannot be reproduced without real Apple signatures, and stubbing the `SignedDataVerifier` heavily would create test debt for little signal. Handler behavior is verified end-to-end on Sandbox + TestFlight (Phase 7).

---

## File Structure

**Backend (DB):**
- Modify: `supabase/schemas/subscription/tables/user_subscriptions.sql` — add `apple_original_transaction_id` column + index
- Create (auto-generated, then DML appended): `supabase/migrations/<timestamp>_add_apple_iap_support.sql`
- Create: `supabase/tests/database/user_subscriptions_apple_column.test.sql`
- Create: `supabase/tests/database/subscription_plan_prices_apple.test.sql`

**Backend (Edge Function):**
- Create: `supabase/functions/handle-app-store-server-notification/index.ts`
- Create: `supabase/functions/handle-app-store-server-notification/deno.json`
- Create: `supabase/functions/handle-app-store-server-notification/.npmrc` (auto by `functions new`)
- Create: `supabase/functions/handle-app-store-server-notification/helpers.ts`
- Create: `supabase/functions/handle-app-store-server-notification/helpers.test.ts`
- Create: `supabase/functions/handle-app-store-server-notification/certs/AppleRootCA-G2.cer`
- Create: `supabase/functions/handle-app-store-server-notification/certs/AppleRootCA-G3.cer`
- Create: `supabase/functions/handle-app-store-server-notification/certs/AppleComputerRootCertificate.cer`
- Modify: `supabase/config.toml` — register `[functions.handle-app-store-server-notification]` with `verify_jwt = false` and `static_files`

**Flutter:**
- Modify: `peppercheck_flutter/lib/features/billing/presentation/widgets/plan_selection_bottom_sheet.dart` — branch cancel URL/label by platform
- Modify: `peppercheck_flutter/lib/features/account/presentation/widgets/support_section.dart` — convert to `ConsumerWidget`, add iOS-only Restore Purchases tile
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json` — add `billing.cancelViaAppStore`, `billing.restorePurchases`, `billing.restoreSucceeded`, `billing.restoreFailed`
- Auto-regenerated: `peppercheck_flutter/lib/gen/slang/strings.g.dart`

---

## Phase 1 — DB schema and seed data

### Task 1: Add `apple_original_transaction_id` column to schema

**Files:**
- Modify: `supabase/schemas/subscription/tables/user_subscriptions.sql`
- Auto-generate: `supabase/migrations/<timestamp>_add_apple_iap_support.sql`

- [ ] **Step 1: Edit the schema file**

Replace `supabase/schemas/subscription/tables/user_subscriptions.sql` with:

```sql
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    user_id uuid NOT NULL,
    plan_id text NOT NULL,
    status public.subscription_status NOT NULL,
    provider public.subscription_provider NOT NULL,

    -- External IDs
    stripe_subscription_id text,
    google_purchase_token text,
    apple_original_transaction_id text,

    current_period_start timestamp with time zone NOT NULL,
    current_period_end timestamp with time zone NOT NULL,

    cancel_at_period_end boolean DEFAULT false NOT NULL,

    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,

    CONSTRAINT user_subscriptions_pkey PRIMARY KEY (user_id),
    CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT user_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id)
);

ALTER TABLE public.user_subscriptions OWNER TO postgres;

-- Indexes
CREATE INDEX idx_user_subscriptions_stripe_id ON public.user_subscriptions USING btree (stripe_subscription_id);
CREATE INDEX idx_user_subscriptions_provider ON public.user_subscriptions USING btree (provider, status);
CREATE INDEX idx_user_subscriptions_apple_id ON public.user_subscriptions USING btree (apple_original_transaction_id);
```

- [ ] **Step 2: Generate the migration via `db diff`**

```bash
supabase db diff -f add_apple_iap_support
```

Expected: a new file `supabase/migrations/<timestamp>_add_apple_iap_support.sql` containing `ALTER TABLE ... ADD COLUMN apple_original_transaction_id text` and `CREATE INDEX idx_user_subscriptions_apple_id`.

- [ ] **Step 3: Verify the generated file contains only the expected diff**

Read the generated migration. Confirm only the column add + index appear (no unrelated noise). If unrelated diffs show up, investigate before continuing — do not edit them away blindly.

- [ ] **Step 4: Commit the DDL**

```bash
git add supabase/schemas/subscription/tables/user_subscriptions.sql supabase/migrations/<timestamp>_add_apple_iap_support.sql
git commit -m "feat(supabase): add apple_original_transaction_id to user_subscriptions"
```

---

### Task 2: Append Apple price seed and Google premium price alignment to the same migration

**Files:**
- Modify: `supabase/migrations/<timestamp>_add_apple_iap_support.sql` (the file generated in Task 1)

- [ ] **Step 1: Append the DML to the migration file**

Append at the bottom of `supabase/migrations/<timestamp>_add_apple_iap_support.sql`:

```sql
-- DML, not detected by schema diff

-- Apple subscription prices (Issue #402)
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

- [ ] **Step 2: Run a fresh DB reset to verify the full migration history applies cleanly**

> Per the user's `feedback_verify_destructive_ops` rule, ask the user to run the script themselves rather than running it for them.

Ask the user to run:

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

Expected: ends with `==> Done!` and no SQL errors.

- [ ] **Step 3: Spot-check the seeded data**

```bash
docker exec supabase_db_supabase psql -U postgres -c "SELECT plan_id, provider, amount_minor FROM public.subscription_plan_prices WHERE provider IN ('apple','google') AND plan_id IN ('light','standard','premium') ORDER BY provider, plan_id;"
```

Expected (rows):

```
 plan_id  | provider | amount_minor
----------+----------+--------------
 light    | apple    |          650
 premium  | apple    |         2480
 standard | apple    |         1280
 light    | google   |          650
 premium  | google   |         2480
 standard | google   |         1280
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/<timestamp>_add_apple_iap_support.sql
git commit -m "feat(supabase): seed Apple plan prices and align Google premium to 2480"
```

---

### Task 3: pgTAP test — `apple_original_transaction_id` column

**Files:**
- Create: `supabase/tests/database/user_subscriptions_apple_column.test.sql`

- [ ] **Step 1: Write the test**

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

SELECT has_column(
    'public', 'user_subscriptions', 'apple_original_transaction_id',
    'apple_original_transaction_id column exists on user_subscriptions'
);

SELECT col_type_is(
    'public', 'user_subscriptions', 'apple_original_transaction_id', 'text',
    'apple_original_transaction_id is type text'
);

SELECT col_is_null(
    'public', 'user_subscriptions', 'apple_original_transaction_id',
    'apple_original_transaction_id is nullable'
);

SELECT has_index(
    'public', 'user_subscriptions', 'idx_user_subscriptions_apple_id',
    ARRAY['apple_original_transaction_id'],
    'idx_user_subscriptions_apple_id index exists'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Run the test**

```bash
docker cp supabase/tests/database/user_subscriptions_apple_column.test.sql supabase_db_supabase:/tmp/
docker exec supabase_db_supabase psql -U postgres -f /tmp/user_subscriptions_apple_column.test.sql
```

Expected: 4 OK lines, no failures.

- [ ] **Step 3: Commit**

```bash
git add supabase/tests/database/user_subscriptions_apple_column.test.sql
git commit -m "test(supabase): pgTAP for apple_original_transaction_id column and index"
```

---

### Task 4: pgTAP test — Apple plan prices and Google premium alignment

**Files:**
- Create: `supabase/tests/database/subscription_plan_prices_apple.test.sql`

- [ ] **Step 1: Write the test**

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'light' AND provider = 'apple' AND currency_code = 'JPY'),
    650,
    'Apple light plan is JPY 650'
);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'standard' AND provider = 'apple' AND currency_code = 'JPY'),
    1280,
    'Apple standard plan is JPY 1280'
);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'premium' AND provider = 'apple' AND currency_code = 'JPY'),
    2480,
    'Apple premium plan is JPY 2480'
);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'premium' AND provider = 'google' AND currency_code = 'JPY'),
    2480,
    'Google premium plan aligned to JPY 2480 (Issue #411)'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Run the test**

```bash
docker cp supabase/tests/database/subscription_plan_prices_apple.test.sql supabase_db_supabase:/tmp/
docker exec supabase_db_supabase psql -U postgres -f /tmp/subscription_plan_prices_apple.test.sql
```

Expected: 4 OK lines.

- [ ] **Step 3: Commit**

```bash
git add supabase/tests/database/subscription_plan_prices_apple.test.sql
git commit -m "test(supabase): pgTAP for Apple plan prices and Google premium alignment"
```

---

### Task 5: Run the full pgTAP regression

- [ ] **Step 1: Run all database tests**

```bash
for f in supabase/tests/database/*.test.sql; do
  echo "=== Running $f ==="
  docker cp "$f" supabase_db_supabase:/tmp/
  docker exec supabase_db_supabase psql -U postgres -f "/tmp/$(basename "$f")"
  echo ""
done
```

Expected: every file ends with all assertions passing. Stop and investigate on any failure (do not proceed to Phase 2 until clean).

---

## Phase 2 — Edge Function scaffold

### Task 6: Generate the function skeleton via Supabase CLI

**Files:**
- Create (via CLI): `supabase/functions/handle-app-store-server-notification/index.ts`
- Create (via CLI): `supabase/functions/handle-app-store-server-notification/deno.json`
- Create (via CLI): `supabase/functions/handle-app-store-server-notification/.npmrc`
- Modify: `supabase/config.toml`

- [ ] **Step 1: Run the generator**

```bash
supabase functions new handle-app-store-server-notification
```

Expected: three files created under `supabase/functions/handle-app-store-server-notification/`.

- [ ] **Step 2: Replace `deno.json` imports**

Overwrite `supabase/functions/handle-app-store-server-notification/deno.json`:

```json
{
  "imports": {
    "@supabase/supabase-js": "jsr:@supabase/supabase-js@2",
    "@apple/app-store-server-library": "npm:@apple/app-store-server-library@^1",
    "@std/assert": "jsr:@std/assert@1"
  }
}
```

- [ ] **Step 3: Register the function in `supabase/config.toml`**

Append to the bottom of `supabase/config.toml`:

```toml
[functions.handle-app-store-server-notification]
enabled = true
verify_jwt = false
import_map = "./functions/handle-app-store-server-notification/deno.json"
entrypoint = "./functions/handle-app-store-server-notification/index.ts"
static_files = [ "./functions/handle-app-store-server-notification/certs/*" ]
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/handle-app-store-server-notification supabase/config.toml
git commit -m "chore(supabase): scaffold handle-app-store-server-notification function"
```

---

### Task 7: Bundle Apple Root CA certificates

**Files:**
- Create: `supabase/functions/handle-app-store-server-notification/certs/AppleRootCA-G2.cer`
- Create: `supabase/functions/handle-app-store-server-notification/certs/AppleRootCA-G3.cer`
- Create: `supabase/functions/handle-app-store-server-notification/certs/AppleComputerRootCertificate.cer`

> These are public Apple root certificates (same as those preloaded into every macOS / iOS trust store). Safe to commit to git.

- [ ] **Step 1: Create the certs directory and download the three files**

```bash
mkdir -p supabase/functions/handle-app-store-server-notification/certs
```

```bash
curl -fsSLo supabase/functions/handle-app-store-server-notification/certs/AppleComputerRootCertificate.cer https://www.apple.com/appleca/AppleIncRootCertificate.cer
```

```bash
curl -fsSLo supabase/functions/handle-app-store-server-notification/certs/AppleRootCA-G2.cer https://www.apple.com/certificateauthority/AppleRootCA-G2.cer
```

```bash
curl -fsSLo supabase/functions/handle-app-store-server-notification/certs/AppleRootCA-G3.cer https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
```

- [ ] **Step 2: Verify file presence and non-trivial size**

```bash
ls -l supabase/functions/handle-app-store-server-notification/certs/
```

Expected: three `.cer` files, each between roughly 0.9 KB and 2 KB.

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/handle-app-store-server-notification/certs/
git commit -m "chore(supabase): bundle Apple Root CA certs for ASSN handler"
```

---

### Task 8: Pure helpers — `extractPlanId` and `mapNotificationToStatus`

**Files:**
- Create: `supabase/functions/handle-app-store-server-notification/helpers.ts`
- Create: `supabase/functions/handle-app-store-server-notification/helpers.test.ts`

- [ ] **Step 1: Write the failing tests**

Create `supabase/functions/handle-app-store-server-notification/helpers.test.ts`:

```typescript
import { assertEquals } from '@std/assert'
import { extractPlanId, mapNotificationToStatus } from './helpers.ts'

Deno.test('extractPlanId strips _monthly suffix', () => {
  assertEquals(extractPlanId('light_monthly'), 'light')
  assertEquals(extractPlanId('standard_monthly'), 'standard')
  assertEquals(extractPlanId('premium_monthly'), 'premium')
})

Deno.test('extractPlanId is a no-op when suffix is absent', () => {
  assertEquals(extractPlanId('light'), 'light')
})

Deno.test('mapNotificationToStatus: SUBSCRIBED → active', () => {
  assertEquals(mapNotificationToStatus('SUBSCRIBED', 'INITIAL_BUY'), 'active')
  assertEquals(mapNotificationToStatus('SUBSCRIBED', 'RESUBSCRIBE'), 'active')
})

Deno.test('mapNotificationToStatus: DID_RENEW → active (with or without subtype)', () => {
  assertEquals(mapNotificationToStatus('DID_RENEW', undefined), 'active')
  assertEquals(mapNotificationToStatus('DID_RENEW', 'BILLING_RECOVERY'), 'active')
})

Deno.test('mapNotificationToStatus: DID_FAIL_TO_RENEW → past_due (with or without GRACE_PERIOD)', () => {
  assertEquals(mapNotificationToStatus('DID_FAIL_TO_RENEW', 'GRACE_PERIOD'), 'past_due')
  assertEquals(mapNotificationToStatus('DID_FAIL_TO_RENEW', undefined), 'past_due')
})

Deno.test('mapNotificationToStatus: terminal types → canceled', () => {
  assertEquals(mapNotificationToStatus('EXPIRED', undefined), 'canceled')
  assertEquals(mapNotificationToStatus('GRACE_PERIOD_EXPIRED', undefined), 'canceled')
  assertEquals(mapNotificationToStatus('REFUND', undefined), 'canceled')
  assertEquals(mapNotificationToStatus('REVOKE', undefined), 'canceled')
})

Deno.test('mapNotificationToStatus: types handled separately return null', () => {
  assertEquals(mapNotificationToStatus('TEST', undefined), null)
  assertEquals(mapNotificationToStatus('PRICE_INCREASE', undefined), null)
  assertEquals(mapNotificationToStatus('DID_CHANGE_RENEWAL_STATUS', 'AUTO_RENEW_DISABLED'), null)
  assertEquals(mapNotificationToStatus('DID_CHANGE_RENEWAL_STATUS', 'AUTO_RENEW_ENABLED'), null)
  assertEquals(mapNotificationToStatus('DID_CHANGE_RENEWAL_PREF', undefined), null)
})
```

- [ ] **Step 2: Run the tests (expect FAIL — `helpers.ts` does not exist)**

```bash
cd supabase/functions/handle-app-store-server-notification && deno test helpers.test.ts
```

Expected: failure with `Module not found: helpers.ts` or similar.

- [ ] **Step 3: Implement the helpers**

Create `supabase/functions/handle-app-store-server-notification/helpers.ts`:

```typescript
// Apple productId is '{planId}_monthly'; DB plan_id is '{planId}'.
// Mirrors handle-google-play-rtdn extractPlanId.
export function extractPlanId(productId: string): string {
  return productId.replace('_monthly', '')
}

// Maps Apple ASSN V2 notificationType (and subtype, when relevant) to the
// public.subscription_status enum. Returns null when status is not the right
// thing to update for this notification (DID_CHANGE_RENEWAL_STATUS toggles
// cancel_at_period_end only; TEST / PRICE_INCREASE are log-only;
// DID_CHANGE_RENEWAL_PREF carries a plan change but preserves status).
export function mapNotificationToStatus(
  notificationType: string,
  _subtype: string | undefined,
): string | null {
  switch (notificationType) {
    case 'SUBSCRIBED':
    case 'DID_RENEW':
      return 'active'
    case 'DID_FAIL_TO_RENEW':
      return 'past_due'
    case 'EXPIRED':
    case 'GRACE_PERIOD_EXPIRED':
    case 'REFUND':
    case 'REVOKE':
      return 'canceled'
    default:
      return null
  }
}
```

- [ ] **Step 4: Run the tests (expect PASS)**

```bash
cd supabase/functions/handle-app-store-server-notification && deno test helpers.test.ts
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/handle-app-store-server-notification/helpers.ts supabase/functions/handle-app-store-server-notification/helpers.test.ts
git commit -m "feat(supabase): add ASSN helpers (extractPlanId, mapNotificationToStatus)"
```

---

## Phase 3 — Edge Function handler

> **Test note:** the handler is verified end-to-end on Sandbox + TestFlight (Phase 7). No Deno tests are written for the handler — JWS verification cannot be reproduced without real Apple signatures, and stubbing `SignedDataVerifier` heavily would create test debt.

### Task 9: Implement the full handler

**Files:**
- Modify: `supabase/functions/handle-app-store-server-notification/index.ts`

- [ ] **Step 1: Replace `index.ts` with the full handler**

Overwrite `supabase/functions/handle-app-store-server-notification/index.ts`:

```typescript
import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'
import { createClient } from '@supabase/supabase-js'
import {
  Environment,
  SignedDataVerifier,
} from '@apple/app-store-server-library'
import { extractPlanId, mapNotificationToStatus } from './helpers.ts'

const DEFAULT_BUNDLE_ID = 'dev.cloveclove.peppercheck'

async function loadAppleRootCAs(): Promise<Uint8Array[]> {
  const baseUrl = new URL('./certs/', import.meta.url)
  const files = [
    'AppleRootCA-G2.cer',
    'AppleRootCA-G3.cer',
    'AppleComputerRootCertificate.cer',
  ]
  return await Promise.all(
    files.map((f) => Deno.readFile(new URL(f, baseUrl))),
  )
}

let cachedVerifier: SignedDataVerifier | null = null

async function getVerifier(): Promise<SignedDataVerifier> {
  if (cachedVerifier) return cachedVerifier
  const env = Deno.env.get('APPLE_ENVIRONMENT') === 'Production'
    ? Environment.PRODUCTION
    : Environment.SANDBOX
  const rootCAs = await loadAppleRootCAs()
  cachedVerifier = new SignedDataVerifier(
    rootCAs,
    true, // enableOnlineChecks (OCSP)
    env,
    Deno.env.get('APPLE_BUNDLE_ID') ?? DEFAULT_BUNDLE_ID,
  )
  return cachedVerifier
}

interface DispatchInput {
  notificationType: string
  subtype: string | undefined
  // deno-lint-ignore no-explicit-any
  transactionInfo: any
  // deno-lint-ignore no-explicit-any
  renewalInfo: any
  userId: string
  // deno-lint-ignore no-explicit-any
  supabaseAdmin: any
}

async function upsertSubscription(
  input: DispatchInput,
  status: string,
): Promise<void> {
  const { transactionInfo, renewalInfo, userId, supabaseAdmin } = input
  const { error } = await supabaseAdmin.from('user_subscriptions').upsert({
    user_id: userId,
    plan_id: extractPlanId(transactionInfo.productId),
    status,
    provider: 'apple',
    apple_original_transaction_id: transactionInfo.originalTransactionId,
    current_period_start: new Date(transactionInfo.purchaseDate).toISOString(),
    current_period_end: new Date(transactionInfo.expiresDate).toISOString(),
    cancel_at_period_end: renewalInfo ? renewalInfo.autoRenewStatus === 0 : false,
    updated_at: new Date().toISOString(),
  })
  if (error) throw error
}

async function resetPoints(input: DispatchInput): Promise<void> {
  const { transactionInfo, userId, supabaseAdmin } = input
  const planId = extractPlanId(transactionInfo.productId)
  const { data: planData, error: planError } = await supabaseAdmin
    .from('subscription_plans')
    .select('monthly_points')
    .eq('id', planId)
    .single()
  if (planError || !planData) {
    throw new Error(`Plan not found: ${planId}`)
  }
  if (planData.monthly_points <= 0) return
  const invoiceId = `apple:${transactionInfo.transactionId}`
  const { data: granted, error } = await supabaseAdmin.rpc(
    'reset_subscription_points',
    {
      p_user_id: userId,
      p_amount: planData.monthly_points,
      p_invoice_id: invoiceId,
    },
  )
  if (error) throw error
  if (granted) {
    console.log(`Reset points to ${planData.monthly_points} for user ${userId}`)
  } else {
    console.log(`Points already reset for ${invoiceId} (idempotent)`)
  }
}

async function deactivateTrial(input: DispatchInput): Promise<void> {
  const { userId, supabaseAdmin } = input
  const { error } = await supabaseAdmin.rpc('deactivate_trial_points', {
    p_user_id: userId,
  })
  if (error) {
    // Best-effort; subscription activation already succeeded.
    console.error(`Failed to deactivate trial points for user ${userId}:`, error)
  }
}

async function dispatch(input: DispatchInput): Promise<void> {
  const { notificationType, subtype, userId, supabaseAdmin } = input

  if (notificationType === 'TEST' || notificationType === 'PRICE_INCREASE') {
    return
  }

  if (notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
    const cancelAtPeriodEnd = subtype === 'AUTO_RENEW_DISABLED'
    const { error } = await supabaseAdmin
      .from('user_subscriptions')
      .update({
        cancel_at_period_end: cancelAtPeriodEnd,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)
    if (error) throw error
    return
  }

  if (notificationType === 'SUBSCRIBED') {
    await upsertSubscription(input, 'active')
    await resetPoints(input)
    if (subtype === 'INITIAL_BUY') {
      await deactivateTrial(input)
    }
    return
  }

  if (notificationType === 'DID_RENEW') {
    await upsertSubscription(input, 'active')
    await resetPoints(input)
    return
  }

  if (notificationType === 'DID_CHANGE_RENEWAL_PREF') {
    await upsertSubscription(input, 'active')
    return
  }

  const mappedStatus = mapNotificationToStatus(notificationType, subtype)
  if (mappedStatus) {
    await upsertSubscription(input, mappedStatus)
  }
}

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
    const verifier = await getVerifier()

    const decoded = await verifier.verifyAndDecodeNotification(body.signedPayload)
    const { notificationType, subtype, data } = decoded
    console.log(
      `ASSN: env=${data?.environment ?? '-'} type=${notificationType} subtype=${subtype ?? '-'}`,
    )

    if (!data?.signedTransactionInfo) {
      return new Response(JSON.stringify({ received: true }), { status: 200 })
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

    await dispatch({
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
    // Always 200 — Apple retries non-2xx for up to 3 days, max 5 times.
    // Failed processing is investigated via logs, not retried automatically.
    return new Response(JSON.stringify({ error: 'processing failed' }), { status: 200 })
  }
})
```

- [ ] **Step 2: Type-check the file**

```bash
cd supabase/functions/handle-app-store-server-notification && deno check index.ts
```

Expected: no type errors.

If `npm:@apple/app-store-server-library` types fail to resolve under Deno's npm specifier (Risk R3), add `// @ts-ignore Deno npm: type resolution for @apple/app-store-server-library` immediately above the import line and continue. Surface the issue to the user — if the runtime later fails on the SDK as well, fall back to `jose` + a hand-rolled X.509 chain validator (Q5 alt in the spec).

- [ ] **Step 3: Re-run the helper tests as a sanity check**

```bash
cd supabase/functions/handle-app-store-server-notification && deno test helpers.test.ts
```

Expected: all tests still pass (helpers untouched).

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/handle-app-store-server-notification/index.ts
git commit -m "feat(supabase): handle App Store Server Notifications V2"
```

---

## Phase 4 — Flutter changes

### Task 10: Cancel-link platform branching in plan selection sheet

**Files:**
- Modify: `peppercheck_flutter/lib/features/billing/presentation/widgets/plan_selection_bottom_sheet.dart`
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`
- Auto-regenerated: `peppercheck_flutter/lib/gen/slang/strings.g.dart`

- [ ] **Step 1: Add the i18n key**

In `peppercheck_flutter/assets/i18n/ja.i18n.json`, inside the `"billing"` object, add a new key right after `"cancelViaGooglePlay"`:

```json
    "cancelViaGooglePlay": "キャンセルはGoogle Playから →",
    "cancelViaAppStore": "キャンセルはApp Storeから →",
```

- [ ] **Step 2: Branch the cancel link in the bottom sheet**

In `peppercheck_flutter/lib/features/billing/presentation/widgets/plan_selection_bottom_sheet.dart`:

1. Add `import 'dart:io';` at the top of the file.
2. Replace the `if (showCancelLink) ...[ ... ]` block (around lines 88–114) with:

```dart
              if (showCancelLink) ...[
                const SizedBox(height: AppSizes.spacingMedium),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => launchUrl(
                      Uri.parse(
                        Platform.isIOS
                            ? 'https://apps.apple.com/account/subscriptions'
                            : 'https://play.google.com/store/account/subscriptions',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spacingTiny,
                      ),
                      child: Text(
                        Platform.isIOS
                            ? t.billing.cancelViaAppStore
                            : t.billing.cancelViaGooglePlay,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
```

- [ ] **Step 3: Regenerate slang i18n**

```bash
cd peppercheck_flutter && dart run slang
```

Expected: `lib/gen/slang/strings.g.dart` regenerated, no errors.

- [ ] **Step 4: Verify the Flutter build still compiles**

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk.`

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/features/billing/presentation/widgets/plan_selection_bottom_sheet.dart peppercheck_flutter/assets/i18n/ja.i18n.json peppercheck_flutter/lib/gen/slang/strings.g.dart
git commit -m "feat(flutter): branch cancel-link target by platform (iOS → App Store)"
```

---

### Task 11: iOS-only "Restore Purchases" tile in `SupportSection`

**Files:**
- Modify: `peppercheck_flutter/lib/features/account/presentation/widgets/support_section.dart`
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`
- Auto-regenerated: `peppercheck_flutter/lib/gen/slang/strings.g.dart`

- [ ] **Step 1: Add three i18n keys**

In `peppercheck_flutter/assets/i18n/ja.i18n.json`, inside the `"billing"` object, add (right after `cancelViaAppStore`):

```json
    "restorePurchases": "購入を復元",
    "restoreSucceeded": "購入を復元しました",
    "restoreFailed": "購入の復元に失敗しました",
```

- [ ] **Step 2: Replace `support_section.dart` with the ConsumerWidget version**

Overwrite `peppercheck_flutter/lib/features/account/presentation/widgets/support_section.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/about/presentation/app_explanation_bottom_sheet.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/presentation/in_app_purchase_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportSection extends ConsumerWidget {
  const SupportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseSection(
      title: t.support.title,
      child: Column(
        children: [
          _LinkTile(
            title: t.support.aboutPeppercheck,
            onTap: () => showAppExplanationBottomSheet(context),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          _LinkTile(
            title: t.support.termsOfService,
            onTap: () => _launchLegalPage('terms'),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          _LinkTile(
            title: t.support.privacyPolicy,
            onTap: () => _launchLegalPage('privacy'),
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: AppSizes.spacingSmall),
            _LinkTile(
              title: t.billing.restorePurchases,
              onTap: () => _restorePurchases(context, ref),
            ),
          ],
          const SizedBox(height: AppSizes.spacingSmall),
          _LinkTile(
            title: t.support.contactUs,
            onTap: () => _launchUrl('mailto:hi@cloveclove.dev'),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(inAppPurchaseControllerProvider.notifier)
          .restorePurchases();
      ref.invalidate(subscriptionProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(t.billing.restoreSucceeded)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.billing.restoreFailed)),
      );
    }
  }

  Future<void> _launchLegalPage(String page) async {
    // WEB_DASHBOARD_URL is expected to end with /dashboard (see .env.example)
    final dashboardUrl =
        dotenv.env['WEB_DASHBOARD_URL'] ?? 'http://localhost:3000/dashboard';
    final baseUrl = dashboardUrl.replaceAll(RegExp(r'/dashboard$'), '');
    final locale = LocaleSettings.currentLocale.languageCode;
    await _launchUrl('$baseUrl/$locale/legal/$page');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingTiny),
        child: Row(
          children: [
            Expanded(child: Text(title)),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Regenerate slang i18n and verify build**

```bash
cd peppercheck_flutter && dart run slang
```

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/account/presentation/widgets/support_section.dart peppercheck_flutter/assets/i18n/ja.i18n.json peppercheck_flutter/lib/gen/slang/strings.g.dart
git commit -m "feat(flutter): add iOS-only Restore Purchases link to SupportSection"
```

---

## Phase 5 — Deploy and manual App Store Connect setup

### Task 12: Deploy DB migration and Edge Function to staging Supabase

> **Operator-supervised step.** Confirm the staging project ref before running each command and ask the user before running anything destructive on staging.

- [ ] **Step 1: Confirm linked project**

```bash
supabase status
```

Expected output includes the staging project ref. If it's pointing somewhere else, run `supabase link --project-ref <staging-project-ref>` first.

- [ ] **Step 2: Push DB migrations to staging**

Ask the user to confirm before running:

```bash
supabase db push
```

Expected: `add_apple_iap_support` migration applies successfully. If staging is far behind, surface the diff to the operator before proceeding.

- [ ] **Step 3: Set Edge Function secrets**

```bash
supabase secrets set APPLE_BUNDLE_ID=dev.cloveclove.peppercheck APPLE_ENVIRONMENT=Sandbox
```

(`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected by Supabase.)

- [ ] **Step 4: Deploy the Edge Function**

```bash
supabase functions deploy handle-app-store-server-notification
```

Expected: `Deployed Function ... to project <staging-project-ref>`.

- [ ] **Step 5: Smoke-test reachability**

```bash
curl -i -X POST "https://<staging-project-ref>.supabase.co/functions/v1/handle-app-store-server-notification" \
  -H 'Content-Type: application/json' \
  -d '{"signedPayload":"not-a-real-jws"}'
```

Expected: `HTTP/2 200` with `{"error":"processing failed"}` body. (The function intentionally returns 200 even on JWS verification failure — Apple's retry policy assumes anything non-2xx will be retried for 3 days.)

In Supabase logs (`Functions` tab), confirm a single `Error processing ASSN: ...` entry for that request.

> **No commit.** This task is operator-side configuration.

---

### Task 13: App Store Connect manual setup

> **Operator-only checklist** — there is no code or commit in this task. The agent records progress in the plan; the operator performs each step in the App Store Connect / Apple Developer Portal web UIs.

- [ ] **Apple Developer Portal — App ID**: Identifiers → Register App ID with bundle `dev.cloveclove.peppercheck` (Explicit), Description `PepperCheck`. Enable In-App Purchase and Push Notifications.

- [ ] **App Store Connect — App record**: My Apps → New App. Platforms iOS, Name PepperCheck, Primary Language Japanese, Bundle ID `dev.cloveclove.peppercheck`, SKU `dev.cloveclove.peppercheck`, User Access Full Access.

- [ ] **Subscription Group**: Monetization → Subscriptions → New group. Reference Name `main_subscription`, Display Name (ja) `プラン`.

- [ ] **Subscription products** (in `main_subscription`):
  - `light_monthly` — Reference Name `Light Monthly`, Group Level 3, JPY 650, Family Sharing OFF, Auto-Renewable, 1 month, ja localization: `ライトプラン` / `毎月5ポイントが付与されます。`
  - `standard_monthly` — Group Level 2, JPY 1,280, ja localization: `スタンダードプラン` / `毎月10ポイントが付与されます。`
  - `premium_monthly` — Group Level 1, JPY 2,480, ja localization: `プレミアムプラン` / `毎月20ポイントが付与されます。`
  - Availability: Japan only on every product.

- [ ] **App Store Server Notifications V2**: App Information → ASSN → Version 2. Sandbox URL `https://<staging-project-ref>.supabase.co/functions/v1/handle-app-store-server-notification`. Production URL left blank for now. Leave the V1 Subscription Status URL empty.

- [ ] **Send Test Notification**: ASC → ASSN → Send Test Notification. Verify in staging Supabase logs that the function received the request, decoded a `TEST` notification type, and returned 200.

- [ ] **Sandbox tester**: Users and Access → Sandbox → Testers → create one fresh-email Sandbox tester (Country: Japan).

- [ ] **Update Issue #402**: Mark the three checklist items (App ID registered / App created in ASC / IAP capability enabled) as done.

- [ ] **Google Play Console (#411)**: Play Console → Monetize → Subscriptions → `premium_monthly` → set price to ¥2,480. (No grace-period notification needed — zero current paying users.)

---

## Phase 6 — End-to-end verification

### Task 14: Sandbox scenarios A through G on a physical iOS device

> Build/run the staging-flavored Flutter app on a real iOS device signed in with the sandbox tester account (Settings → App Store → Sandbox Account). Local emulators cannot complete StoreKit purchases.

> **Before the first iOS build of this branch**, run from the repo root:
>
> ```bash
> cd peppercheck_flutter && flutter pub get
> ```
>
> ```bash
> cd peppercheck_flutter/ios && pod install
> ```
>
> No `pubspec.yaml` change is needed — `in_app_purchase_storekit` is auto-resolved via the federated `in_app_purchase` plugin. `pod install` materializes the StoreKit pods on the iOS side.

- [ ] **A. New purchase (Light)**
  1. Wallet → Choose Plan → Light → confirm Apple UI.
  2. Edge Function logs: `notificationType: SUBSCRIBED`, subtype `INITIAL_BUY`.
  3. DB: `user_subscriptions` row with `provider='apple'`, `plan_id='light'`, `status='active'`, `apple_original_transaction_id` populated.
  4. DB: `point_ledger` has `+5` granted with `description = 'Subscription renewal: apple:<transactionId>'`.
  5. DB: `trial_point_wallets.is_active = false` for the user.
  6. UI: progressive polling (`[1, 1, 2, 2, 3]`s) flips to `ライトプラン契約中` within ~9 seconds.

- [ ] **B. Auto-renewal (Sandbox cadence is 5 minutes for monthly)**
  1. Wait ~5 minutes after A. Edge Function logs: `notificationType: DID_RENEW`.
  2. DB: `current_period_end` advanced; new `point_ledger` `+5` row with a different `apple:<transactionId>` invoice key.

- [ ] **C. Upgrade (Light → Premium)**
  1. From state A or B, choose Premium → confirm.
  2. Apple performs in-group prorated upgrade.
  3. DB: `plan_id` updates to `premium`. `point_ledger`: `+20` granted (idempotency holds — no double credit on retried notifications).

- [ ] **D. Downgrade (Premium → Light)**
  1. From state C, choose Light → confirm.
  2. Apple defers downgrade until period end. Immediate `plan_id` stays `premium`.
  3. After next sandbox renewal: `DID_RENEW` arrives with productId `light_monthly`; DB `plan_id` becomes `light`.

- [ ] **E. Cancellation**
  1. iOS Settings → Subscriptions → cancel.
  2. Edge Function logs: `DID_CHANGE_RENEWAL_STATUS` + subtype `AUTO_RENEW_DISABLED`.
  3. DB: `cancel_at_period_end = true` for the user. UI shows `解約済み・<date>まで利用可能`.

- [ ] **F. Expiry**
  1. Wait 5 minutes after E. Edge Function logs: `EXPIRED`.
  2. DB: `status = canceled`. App treats user as not subscribed.

- [ ] **G. Restore Purchases**
  1. Reinstall app, log in. `subscriptionProvider` should reflect any active sandbox subscription on first read.
  2. Account → tap `購入を復元` → expect SnackBar `購入を復元しました`. Failure path → `購入の復元に失敗しました`.
  3. Confirm `subscriptionProvider` reflects the active subscription afterwards (the existing `[1, 1, 2, 2, 3]`-second polling loop runs once StoreKit emits the restored purchase via `purchaseStream`; the explicit `ref.invalidate` in Task 11 also nudges the provider).
  4. **iOS `purchaseStream` quirks** (verify, no code change expected): restored iOS `PurchaseDetails` arrive with `status == PurchaseStatus.restored` but the underlying type is `AppStorePurchaseDetails`, not `GooglePlayPurchaseDetails`. Confirm:
     - The `if (purchase is GooglePlayPurchaseDetails)` branch in `in_app_purchase_controller.dart:_onPurchaseUpdate` correctly skips, so `currentPurchaseProvider` is NOT mutated for iOS (it's an Android-only upgrade-flow concern).
     - Restored iOS purchases do NOT flip controller state (they're not new buys).
     - `pendingCompletePurchase` is still honored — `repo.completePurchase(purchase)` runs to acknowledge the purchase to StoreKit.
     - If any of these diverge in real testing, add an explicit `purchase is AppStorePurchaseDetails` branch mirroring the existing GooglePlay one.

> If `transactionInfo.appAccountToken` arrives empty or non-UUID at the Edge Function (Risk R2 in the spec), pause E2E and implement the Method Channel + Swift fallback that calls `Product.purchase(options: [.appAccountToken(uuid)])` directly. Track that work as a follow-up issue and rerun A–G after the fix.

---

### Task 15: TestFlight Internal Testing rerun

- [ ] **Step 1: Archive a TestFlight build**

In Xcode (or via CI), archive the iOS app and upload to App Store Connect. Wait for TestFlight processing.

- [ ] **Step 2: Add internal testers and install via TestFlight on the same physical device.**

- [ ] **Step 3: Repeat scenarios A–G against TestFlight Sandbox.**

Expected outcomes are identical to Task 14.

---

### Task 16: Android regression check

- [ ] **Step 1: Install the staging-flavored Flutter app on a physical Android device** with a Google account distinct from the Apple sandbox tester.

- [ ] **Step 2: Re-run Google Play scenarios** (purchase, renewal, upgrade, downgrade, cancel, expiry) and confirm no regression vs. the baseline. Specifically:
  - Plan-selection sheet still shows `キャンセルはGoogle Playから →` (not the new App Store label).
  - SupportSection does NOT show the Restore Purchases tile (it is iOS-gated).
  - Premium plan price reads ¥2,480 in the plan sheet (Issue #411 alignment).

- [ ] **Step 3: Smoke-check Stripe webhook handling** (no code change here, but the `subscription_plan_prices` premium row was updated). Trigger a test webhook against staging Stripe and confirm `point_ledger` and `user_subscriptions` still update correctly.

---

## Phase 7 — Wrap up

### Task 17: Open the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin <branch-name>
```

- [ ] **Step 2: Open a PR with this body skeleton**

```
## Summary
- iOS IAP: new Edge Function `handle-app-store-server-notification` consumes ASSN V2 and updates user_subscriptions / point ledger.
- DB: adds apple_original_transaction_id column, seeds Apple plan prices, aligns Google premium price to ¥2,480 (#411).
- Flutter: cancel link routes to App Store on iOS; iOS-only Restore Purchases tile in SupportSection.

## Test plan
- [x] pgTAP regression suite passes (Task 5).
- [x] Edge Function helper unit tests pass (Task 8).
- [x] Sandbox A–G on physical iOS device (Task 14).
- [x] TestFlight A–G (Task 15).
- [x] Android regression (Task 16).

Closes #402.
Closes #411.
```

- [ ] **Step 3: Hand off to the operator** for final review and merge.

---

## Risks called out in the spec — handling in this plan

- **R1 (staging readiness)**: Phase 5 Task 12 is an explicit checkpoint. Do not start Phase 6 until staging confirms migrations / secrets / function are deployed.
- **R2 (`appAccountToken` propagation)**: Task 14 has an explicit fallback note. If the field arrives empty/non-UUID, pause E2E and add the Method Channel + Swift workaround.
- **R3 (`app-store-server-library` on Deno)**: Task 9 Step 2 surfaces type-check / runtime errors early. Fall back to `jose` + a hand-rolled X.509 chain validator using the bundled root CAs (Q5 alt in the spec) only if the npm SDK fails on Deno.
- **R4 (first-subscription-with-binary rule)**: Out of scope here; called out in the spec for production submission.
- **R5 (TestFlight 100-user cap)**: Adequate for a solo operator; no action.

## Out of scope (explicit)

- Sign In with Apple (#413).
- Production App Store submission (Review Screenshots, age rating, content rights, screenshots, review notes).
- Promotional / introductory offers (covered by trial points).
- Family Sharing.
- Non-JPY pricing.
- Stripe IAP path on iOS.
