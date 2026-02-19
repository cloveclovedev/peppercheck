# Reward Payout System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Monthly batch payout system that converts Referee reward points to JPY via Stripe Connect transfers.

**Architecture:** Two-phase batch processing. Phase 1 (pg_cron → PL/pgSQL) creates pending payout records. Phase 2 (pg_cron → pg_net → Edge Function) processes them via Stripe transfers every 30 minutes, resuming on timeout.

**Tech Stack:** PostgreSQL (pg_cron, pg_net), Supabase Edge Functions (Deno/TypeScript), Stripe Connect API

**Design Doc:** `docs/plans/2026-02-19-reward-payout-design.md`

---

### Task 1: Create `reward_exchange_rates` table schema

**Files:**
- Create: `supabase/schemas/reward/tables/reward_exchange_rates.sql`
- Modify: `supabase/config.toml` (add to schema_paths)

**Step 1: Create the table schema file**

Create `supabase/schemas/reward/tables/reward_exchange_rates.sql`:

```sql
CREATE TABLE IF NOT EXISTS public.reward_exchange_rates (
    currency text NOT NULL,
    rate_per_point integer NOT NULL,                          -- Minor units per point (JPY: 50 = ¥50)
    active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_exchange_rates_pkey PRIMARY KEY (currency)
);

ALTER TABLE public.reward_exchange_rates OWNER TO postgres;
```

**Step 2: Register in config.toml**

Add after `"./schemas/reward/tables/reward_ledger.sql"` in the `# Reward` tables section:

```toml
  "./schemas/reward/tables/reward_exchange_rates.sql",
```

**Step 3: Commit**

```bash
git add supabase/schemas/reward/tables/reward_exchange_rates.sql supabase/config.toml
git commit -m "feat: add reward_exchange_rates table schema"
```

---

### Task 2: Create `reward_payouts` table schema (with enum in same file)

**Files:**
- Create: `supabase/schemas/reward/tables/reward_payouts.sql`
- Modify: `supabase/config.toml` (add to schema_paths)

**Step 1: Create the table schema file (enum + table together)**

Create `supabase/schemas/reward/tables/reward_payouts.sql`:

```sql
CREATE TYPE public.reward_payout_status AS ENUM (
    'pending',   -- Awaiting Stripe transfer
    'success',   -- Transfer completed
    'failed',    -- Transfer failed (balance preserved, retry next month)
    'skipped'    -- User not ready (no Connect account / payouts not enabled)
);

CREATE TABLE IF NOT EXISTS public.reward_payouts (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    points_amount integer NOT NULL,                           -- Points being paid out
    currency text NOT NULL,                                   -- 'JPY'
    currency_amount integer NOT NULL,                         -- Total payout in minor units (matches Stripe amount convention)
    rate_per_point integer NOT NULL,                          -- Snapshot of rate at time of payout (minor units)
    stripe_transfer_id text,                                  -- Stripe transfer ID on success
    status public.reward_payout_status NOT NULL DEFAULT 'pending',
    error_message text,                                       -- Error details on failure
    batch_date date NOT NULL,                                 -- Date payouts were prepared
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_payouts_pkey PRIMARY KEY (id),
    CONSTRAINT reward_payouts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

ALTER TABLE public.reward_payouts OWNER TO postgres;
```

**Step 2: Register in config.toml**

Add after `reward_exchange_rates.sql` in the `# Reward` tables section:

```toml
  "./schemas/reward/tables/reward_payouts.sql",
```

**Step 3: Commit**

```bash
git add supabase/schemas/reward/tables/reward_payouts.sql supabase/config.toml
git commit -m "feat: add reward_payouts table schema with payout_status enum"
```

---

### Task 3: Create RLS policies for `reward_payouts` and updated_at trigger

**Files:**
- Create: `supabase/schemas/reward/policies/reward_payouts_policies.sql`
- Create: `supabase/schemas/reward/triggers/on_reward_payouts_update_set_updated_at.sql`
- Modify: `supabase/config.toml`

**Step 1: Create RLS policy file**

Create `supabase/schemas/reward/policies/reward_payouts_policies.sql`:

```sql
ALTER TABLE public.reward_payouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reward_payouts: select if self" ON public.reward_payouts
    FOR SELECT
    USING (user_id = (SELECT auth.uid()));
```

**Step 2: Create updated_at trigger**

Create `supabase/schemas/reward/triggers/on_reward_payouts_update_set_updated_at.sql`:

```sql
CREATE TRIGGER on_reward_payouts_update_set_updated_at
    BEFORE UPDATE ON public.reward_payouts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
```

**Step 3: Register in config.toml**

Add trigger after `"./schemas/reward/triggers/on_reward_wallets_update_set_updated_at.sql"`:

```toml
  "./schemas/reward/triggers/on_reward_payouts_update_set_updated_at.sql",
```

Add policy after `"./schemas/reward/policies/reward_ledger_policies.sql"`:

```toml
  "./schemas/reward/policies/reward_payouts_policies.sql",
```

**Step 4: Commit**

```bash
git add supabase/schemas/reward/policies/reward_payouts_policies.sql supabase/schemas/reward/triggers/on_reward_payouts_update_set_updated_at.sql supabase/config.toml
git commit -m "feat: add reward_payouts RLS policy and updated_at trigger"
```

---

### Task 4: Create `deduct_reward_for_payout()` function

**Files:**
- Create: `supabase/schemas/reward/functions/deduct_reward_for_payout.sql`
- Modify: `supabase/config.toml`

**Step 1: Create the function**

Create `supabase/schemas/reward/functions/deduct_reward_for_payout.sql`:

```sql
CREATE OR REPLACE FUNCTION public.deduct_reward_for_payout(
    p_user_id uuid,
    p_amount integer,
    p_payout_id uuid
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    -- Deduct from wallet
    UPDATE public.reward_wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND balance >= p_amount;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient reward balance for user %', p_user_id;
    END IF;

    -- Log to ledger (negative amount for payout)
    INSERT INTO public.reward_ledger (
        user_id,
        amount,
        reason,
        description,
        related_id
    ) VALUES (
        p_user_id,
        -p_amount,
        'payout'::public.reward_reason,
        'Monthly payout',
        p_payout_id
    );
END;
$$;

ALTER FUNCTION public.deduct_reward_for_payout(uuid, integer, uuid) OWNER TO postgres;
```

**Step 2: Register in config.toml**

Add after `"./schemas/reward/functions/grant_reward.sql"`:

```toml
  "./schemas/reward/functions/deduct_reward_for_payout.sql",
```

**Step 3: Commit**

```bash
git add supabase/schemas/reward/functions/deduct_reward_for_payout.sql supabase/config.toml
git commit -m "feat: add deduct_reward_for_payout() function"
```

---

### Task 5: Create `prepare_monthly_payouts()` function

**Files:**
- Create: `supabase/schemas/reward/functions/prepare_monthly_payouts.sql`
- Modify: `supabase/config.toml`

**Step 1: Create the function**

Create `supabase/schemas/reward/functions/prepare_monthly_payouts.sql`:

```sql
CREATE OR REPLACE FUNCTION public.prepare_monthly_payouts(
    p_currency text DEFAULT 'JPY'
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_rate integer;
    v_batch_date date := CURRENT_DATE;
    v_wallet RECORD;
    v_pending_count integer := 0;
    v_skipped_count integer := 0;
    v_connect_account_id text;
    v_payouts_enabled boolean;
BEGIN
    -- Guard: only run on the actual last day of the month
    IF v_batch_date != (date_trunc('month', v_batch_date) + interval '1 month' - interval '1 day')::date THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'Not last day of month');
    END IF;

    -- Get active exchange rate
    SELECT rate_per_point INTO v_rate
    FROM public.reward_exchange_rates
    WHERE currency = p_currency AND active = true;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'No active exchange rate for currency: %', p_currency;
    END IF;

    -- Idempotency: skip if payouts already prepared for this batch_date
    IF EXISTS (SELECT 1 FROM public.reward_payouts WHERE batch_date = v_batch_date LIMIT 1) THEN
        RETURN jsonb_build_object('skipped', true, 'reason', 'Payouts already prepared for ' || v_batch_date);
    END IF;

    -- Process each wallet with balance > 0
    FOR v_wallet IN
        SELECT user_id, balance FROM public.reward_wallets WHERE balance > 0
    LOOP
        -- Check Connect account status
        -- profiles.id = auth.users.id = stripe_accounts.profile_id
        SELECT sa.stripe_connect_account_id, sa.payouts_enabled
        INTO v_connect_account_id, v_payouts_enabled
        FROM public.stripe_accounts sa
        WHERE sa.profile_id = v_wallet.user_id;

        IF v_connect_account_id IS NOT NULL AND v_payouts_enabled = true THEN
            -- User is ready for payout
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'pending', v_batch_date
            );
            v_pending_count := v_pending_count + 1;
        ELSE
            -- User not ready — skip and notify
            INSERT INTO public.reward_payouts (
                user_id, points_amount, currency, currency_amount,
                rate_per_point, status, batch_date, error_message
            ) VALUES (
                v_wallet.user_id, v_wallet.balance, p_currency,
                v_wallet.balance * v_rate, v_rate, 'skipped', v_batch_date,
                'Connect account not ready (payouts_enabled=false or no account)'
            );
            v_skipped_count := v_skipped_count + 1;

            -- Send reminder notification
            PERFORM public.notify_event(
                v_wallet.user_id,
                'notification_payout_connect_required',
                NULL,
                jsonb_build_object('batch_date', v_batch_date)
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'pending', v_pending_count,
        'skipped', v_skipped_count,
        'batch_date', v_batch_date,
        'currency', p_currency,
        'rate_per_point', v_rate
    );
END;
$$;

ALTER FUNCTION public.prepare_monthly_payouts(text) OWNER TO postgres;
```

**Step 2: Register in config.toml**

Add after `deduct_reward_for_payout.sql`:

```toml
  "./schemas/reward/functions/prepare_monthly_payouts.sql",
```

**Step 3: Commit**

```bash
git add supabase/schemas/reward/functions/prepare_monthly_payouts.sql supabase/config.toml
git commit -m "feat: add prepare_monthly_payouts() function"
```

---

### Task 6: Create cron job schemas for both phases

**Files:**
- Create: `supabase/schemas/reward/cron/cron_prepare_monthly_payouts.sql`
- Create: `supabase/schemas/reward/cron/cron_execute_pending_payouts.sql`

Note: Cron schedules are DML and not detected by `db diff`. They will be manually appended to the migration file in Task 10.

**Step 1: Create Phase 1 cron schema**

Create `supabase/schemas/reward/cron/cron_prepare_monthly_payouts.sql`:

```sql
-- Schedule monthly payout preparation on the last day of each month at 00:00 JST (15:00 UTC)
-- Runs on 28-31; the function has an internal guard to only execute on the actual last day
SELECT cron.schedule(
    'prepare-monthly-payouts',
    '0 15 28-31 * *',
    $$SELECT public.prepare_monthly_payouts('JPY')$$
);
```

**Step 2: Create Phase 2 cron schema**

Create `supabase/schemas/reward/cron/cron_execute_pending_payouts.sql`:

Note: Uses `SUPABASE_URL` secret from vault and appends function path. This avoids storing full function URLs as separate secrets.

```sql
-- Execute pending payouts every 30 minutes via Edge Function
-- No-op when no pending records exist
SELECT cron.schedule(
    'execute-pending-payouts',
    '*/30 * * * *',
    $$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url')
              || '/functions/v1/execute-pending-payouts',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000
    )$$
);
```

**Step 3: Commit**

```bash
git add supabase/schemas/reward/cron/cron_prepare_monthly_payouts.sql supabase/schemas/reward/cron/cron_execute_pending_payouts.sql
git commit -m "feat: add cron job schemas for monthly payout phases"
```

---

### Task 7: Create `execute-pending-payouts` Edge Function

**Files:**
- Create via CLI: `supabase/functions/execute-pending-payouts/` (generated)
- Modify: `supabase/functions/execute-pending-payouts/index.ts` (edit generated file)
- Modify: `supabase/config.toml` (add function config)

**Step 1: Generate boilerplate via CLI**

Run: `supabase functions new execute-pending-payouts`

**Step 2: Create deno.json with dependencies**

Edit `supabase/functions/execute-pending-payouts/deno.json`:

```json
{
  "imports": {
    "@supabase/supabase-js": "jsr:@supabase/supabase-js@2",
    "stripe": "npm:stripe@19.3.0"
  }
}
```

**Step 3: Implement the Edge Function**

Replace the generated `supabase/functions/execute-pending-payouts/index.ts` with:

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "@supabase/supabase-js"
import Stripe from "stripe"

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? ""

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2024-11-20.acacia",
})

const jsonHeaders = { "Content-Type": "application/json" }

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders },
    )
  }

  // Verify service role authorization (internal call from pg_cron via pg_net)
  const authHeader = req.headers.get("Authorization")
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing authorization" }),
      { status: 401, headers: jsonHeaders },
    )
  }

  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

  try {
    // Fetch pending payouts
    const { data: payouts, error: fetchError } = await supabase
      .from("reward_payouts")
      .select("id, user_id, points_amount, currency, currency_amount")
      .eq("status", "pending")
      .order("created_at", { ascending: true })

    if (fetchError) {
      console.error("Failed to fetch pending payouts:", fetchError)
      return new Response(
        JSON.stringify({ error: "Failed to fetch payouts" }),
        { status: 500, headers: jsonHeaders },
      )
    }

    if (!payouts || payouts.length === 0) {
      return new Response(
        JSON.stringify({ message: "No pending payouts", processed: 0 }),
        { status: 200, headers: jsonHeaders },
      )
    }

    let successCount = 0
    let failCount = 0

    for (const payout of payouts) {
      try {
        // Get Connect account ID for this user
        // profiles.id = auth.users.id = stripe_accounts.profile_id
        const { data: stripeAccount, error: accountError } = await supabase
          .from("stripe_accounts")
          .select("stripe_connect_account_id")
          .eq("profile_id", payout.user_id)
          .single()

        if (accountError || !stripeAccount?.stripe_connect_account_id) {
          throw new Error(
            `No Connect account for user ${payout.user_id}: ${accountError?.message ?? "missing"}`,
          )
        }

        // Create Stripe Transfer with idempotency key
        const transfer = await stripe.transfers.create(
          {
            amount: payout.currency_amount,
            currency: payout.currency.toLowerCase(),
            destination: stripeAccount.stripe_connect_account_id,
            description: `Peppercheck reward payout - ${payout.points_amount} points`,
            metadata: {
              payout_id: payout.id,
              user_id: payout.user_id,
            },
          },
          {
            idempotencyKey: `payout-${payout.id}`,
          },
        )

        // Mark payout as success
        await supabase
          .from("reward_payouts")
          .update({
            status: "success",
            stripe_transfer_id: transfer.id,
          })
          .eq("id", payout.id)

        // Deduct wallet balance and create ledger entry
        const { error: deductError } = await supabase.rpc(
          "deduct_reward_for_payout",
          {
            p_user_id: payout.user_id,
            p_amount: payout.points_amount,
            p_payout_id: payout.id,
          },
        )

        if (deductError) {
          // Transfer succeeded but deduct failed — needs manual reconciliation
          console.error(
            `CRITICAL: Deduct failed for payout ${payout.id} (transfer ${transfer.id}):`,
            deductError,
          )
        }

        successCount++
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : String(error)
        console.error(`Payout ${payout.id} failed:`, errorMessage)

        // Mark payout as failed
        await supabase
          .from("reward_payouts")
          .update({
            status: "failed",
            error_message: errorMessage.substring(0, 500),
          })
          .eq("id", payout.id)

        // Notify user of failed payout
        await supabase.rpc("notify_event", {
          p_user_id: payout.user_id,
          p_template_key: "notification_payout_failed",
          p_template_args: null,
          p_data: { payout_id: payout.id },
        })

        failCount++
      }
    }

    return new Response(
      JSON.stringify({
        processed: successCount + failCount,
        success: successCount,
        failed: failCount,
      }),
      { status: 200, headers: jsonHeaders },
    )
  } catch (error) {
    console.error("execute-pending-payouts error:", error)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: jsonHeaders },
    )
  }
})
```

**Step 4: Add function config to config.toml**

Add after the `[functions.send-notification]` section:

```toml
[functions.execute-pending-payouts]
enabled = true
verify_jwt = false
import_map = "./functions/execute-pending-payouts/deno.json"
```

**Step 5: Commit**

```bash
git add supabase/functions/execute-pending-payouts/ supabase/config.toml
git commit -m "feat: add execute-pending-payouts Edge Function"
```

---

### Task 8: Add notification templates

**Files:**
- Modify: `peppercheck_flutter/android/app/src/main/res/values/strings.xml`
- Modify: `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`

**Step 1: Add English notification strings**

Add before `</resources>` in `peppercheck_flutter/android/app/src/main/res/values/strings.xml`:

```xml
    <string name="notification_payout_connect_required_title">Payout Setup Required</string>
    <string name="notification_payout_connect_required_body">Complete your payout setup to receive your reward earnings.</string>
    <string name="notification_payout_failed_title">Payout Failed</string>
    <string name="notification_payout_failed_body">Your reward payout could not be processed. Please check your account settings.</string>
```

**Step 2: Add Japanese notification strings**

Add before `</resources>` in `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`:

```xml
    <string name="notification_payout_connect_required_title">報酬受取設定が必要です</string>
    <string name="notification_payout_connect_required_body">報酬を受け取るために振込先の設定を完了してください。</string>
    <string name="notification_payout_failed_title">報酬振込失敗</string>
    <string name="notification_payout_failed_body">報酬の振込に失敗しました。アカウント設定をご確認ください。</string>
```

**Step 3: Commit**

```bash
git add peppercheck_flutter/android/app/src/main/res/values/strings.xml peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml
git commit -m "feat: add payout notification templates (EN/JA)"
```

---

### Task 9: Add vault secret for SUPABASE_URL

**Files:**
- Modify: `supabase/snippets/setup_secrets.sql`

**Step 1: Add the SUPABASE_URL secret**

Check the existing `setup_secrets.sql` and add a `supabase_url` vault secret entry. The cron job in Task 6 reads this and appends the function path.

```sql
SELECT vault.create_secret(
    '<YOUR_SUPABASE_URL>',
    'supabase_url'
);
```

**Step 2: Commit**

```bash
git add supabase/snippets/setup_secrets.sql
git commit -m "feat: add supabase_url vault secret for cron edge function calls"
```

---

### Task 10: Generate migration and append DML

**Step 1: Generate the migration**

Run: `supabase db diff -f add_reward_payout_system`

Expected: Creates a migration file with DDL for new tables, enum, functions, triggers, policies.

**Step 2: Review the generated migration**

Verify it contains:
- `CREATE TYPE public.reward_payout_status`
- `CREATE TABLE public.reward_exchange_rates`
- `CREATE TABLE public.reward_payouts`
- `CREATE FUNCTION public.deduct_reward_for_payout`
- `CREATE FUNCTION public.prepare_monthly_payouts`
- RLS policy on `reward_payouts`
- `updated_at` trigger on `reward_payouts`

**Step 3: Append DML (not detected by db diff)**

Add to the END of the generated migration file:

```sql
-- DML, not detected by schema diff

-- Seed initial exchange rate
INSERT INTO public.reward_exchange_rates (currency, rate_per_point)
VALUES ('JPY', 50);

-- Schedule monthly payout preparation (last day of month, 00:00 JST = 15:00 UTC)
SELECT cron.schedule(
    'prepare-monthly-payouts',
    '0 15 28-31 * *',
    $$SELECT public.prepare_monthly_payouts('JPY')$$
);

-- Schedule pending payout execution every 30 minutes
SELECT cron.schedule(
    'execute-pending-payouts',
    '*/30 * * * *',
    $$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url')
              || '/functions/v1/execute-pending-payouts',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000
    )$$
);
```

**Step 4: Test migration from scratch**

Run: `./scripts/db-reset-and-clear-android-emulators-cache.sh`

Expected: All migrations apply cleanly, no errors.

**Step 5: Commit**

```bash
git add supabase/migrations/
git commit -m "feat: add reward payout system migration"
```

---

### Task 11: Write test snippet

**Files:**
- Create: `supabase/snippets/test_prepare_monthly_payouts.sql`

**Step 1: Create the test snippet**

Create `supabase/snippets/test_prepare_monthly_payouts.sql`:

```sql
-- Test: prepare_monthly_payouts()
-- Run after db-reset to validate the prepare function.
-- NOTE: The function has a last-day-of-month guard.
-- To test on a non-last-day, temporarily comment out the guard.

-- 1. Verify exchange rate exists
SELECT * FROM public.reward_exchange_rates;
-- Expected: JPY | 50 | true

-- 2. Insert test reward wallets (simulate earned rewards)
INSERT INTO public.reward_wallets (user_id, balance)
SELECT id, 5  -- 5 points = 250 JPY
FROM auth.users
LIMIT 2
ON CONFLICT (user_id) DO UPDATE SET balance = 5;

-- 3. Call prepare function
SELECT public.prepare_monthly_payouts('JPY');

-- 4. Check results
SELECT id, user_id, points_amount, currency, currency_amount, rate_per_point, status, error_message, batch_date
FROM public.reward_payouts
ORDER BY created_at DESC;

-- 5. Verify idempotency (calling again should skip)
SELECT public.prepare_monthly_payouts('JPY');
-- Expected: {"skipped": true, "reason": "Payouts already prepared for ..."}

-- 6. Test deduct_reward_for_payout (for a specific payout)
-- SELECT public.deduct_reward_for_payout('<user_id>', 5, '<payout_id>');
-- Then check: SELECT * FROM public.reward_wallets WHERE user_id = '<user_id>';
-- And: SELECT * FROM public.reward_ledger WHERE reason = 'payout' ORDER BY created_at DESC;

-- Cleanup
DELETE FROM public.reward_payouts;
UPDATE public.reward_wallets SET balance = 0;
```

**Step 2: Commit**

```bash
git add supabase/snippets/test_prepare_monthly_payouts.sql
git commit -m "test: add test snippet for prepare_monthly_payouts"
```

---

### Task 12: Create follow-up GitHub issues

**Step 1: Create admin reporting issue**

```bash
gh issue create \
  --title "feat: Admin payout reporting dashboard" \
  --body "Track success/failure rates, monthly totals, batch summaries for reward payouts.

Related: reward payout system (issue#72)

Acceptance criteria:
- Admin can view payout batch history
- Shows success/failure counts per batch
- Shows total JPY transferred per month"
```

**Step 2: Create refined failure classification issue**

```bash
gh issue create \
  --title "feat: Refined payout failure classification" \
  --body "Distinguish user-fault (Connect account issue) vs system-fault (platform balance) in payout failures.

Related: reward payout system (issue#72)

Currently all failures are treated the same. This tracks:
- Different notification messages for different failure types
- Platform balance monitoring/alerts
- Auto-retry logic for transient failures"
```

**Step 3: Create vault secret consolidation issue**

```bash
gh issue create \
  --title "refactor: Consolidate vault secrets to use supabase_url base" \
  --body "Existing cron jobs store full Edge Function URLs as individual vault secrets. Refactor to use a single supabase_url secret and concatenate function paths in SQL.

This reduces the number of secrets to manage and follows the pattern established in the reward payout cron jobs.

Files to update:
- supabase/schemas/judgement/cron/ (evidence timeout, review timeout)
- supabase/snippets/setup_secrets.sql (remove individual function URL secrets)"
```

---

### Summary

| Task | Description | Depends On |
|------|-------------|------------|
| 1 | reward_exchange_rates table | — |
| 2 | reward_payouts table (with enum) | 1 |
| 3 | RLS policies + updated_at trigger | 2 |
| 4 | deduct_reward_for_payout() function | 2 |
| 5 | prepare_monthly_payouts() function | 1, 2, 4 |
| 6 | Cron job schemas | 5 |
| 7 | execute-pending-payouts Edge Function | 4 |
| 8 | Notification templates (EN/JA) | — |
| 9 | Vault secrets setup | — |
| 10 | Generate migration + append DML + test | 1-9 |
| 11 | Test snippet | 10 |
| 12 | Follow-up GitHub issues | — |
