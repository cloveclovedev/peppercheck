# Reward Payout System Design

Date: 2026-02-19
Status: Approved
Related: issue#72

## Overview

Monthly batch payout system that converts Referee reward points to JPY and transfers funds to their bank accounts via Stripe Connect.

Referees earn reward points through completed reviews (1pt for standard, 2pt for premium). At month-end, the system converts accumulated points to JPY using a configurable exchange rate and executes Stripe transfers to each Referee's Connected Express account.

## Architecture: Two-Phase Batch Processing

```
Phase 1: pg_cron → prepare_monthly_payouts() [PL/pgSQL]
  → Creates reward_payouts records for all eligible users
  → Skips users without Connect onboarding + sends reminder

Phase 2: pg_cron (every 30 min) → pg_net → execute-pending-payouts [Edge Function]
  → Processes 'pending' payout records via Stripe transfers
  → Resumable: timeout leaves remaining as 'pending' for next run
```

### Why two phases?

- **Resumable**: If the Edge Function times out, unprocessed payouts remain `pending` and are picked up on the next 30-minute invocation
- **Separation of concerns**: DB handles eligibility/calculation, Edge Function handles Stripe API
- **Idempotent**: Each payout record is processed exactly once (Stripe idempotency keys)
- **Audit trail**: `reward_payouts` table serves as both work queue and audit log

## Database Schema

### New Table: `reward_exchange_rates`

Configurable point-to-currency conversion rates. Designed for future multi-currency support (JPY only for now).

```sql
CREATE TABLE public.reward_exchange_rates (
  currency text NOT NULL PRIMARY KEY,       -- 'JPY', 'USD', etc.
  rate_per_point integer NOT NULL,          -- Minor units per point (JPY: 50 = ¥50)
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Initial data (DML, not detected by schema diff)
INSERT INTO reward_exchange_rates (currency, rate_per_point)
VALUES ('JPY', 50);
```

### New Enum: `reward_payout_status`

```sql
CREATE TYPE public.reward_payout_status AS ENUM (
  'pending',   -- Awaiting Stripe transfer
  'success',   -- Transfer completed
  'failed',    -- Transfer failed (balance preserved, retry next month)
  'skipped'    -- User not ready (no Connect account / payouts not enabled)
);
```

### New Table: `reward_payouts`

Audit trail for each payout attempt. Tracks Stripe transfer IDs, amounts, and failure reasons.

```sql
CREATE TABLE public.reward_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  points_amount integer NOT NULL,       -- Points being paid out
  currency text NOT NULL,               -- 'JPY'
  currency_amount integer NOT NULL,     -- Total payout in minor units (matches Stripe amount convention)
  rate_per_point integer NOT NULL,      -- Snapshot of rate at time of payout (minor units)
  stripe_transfer_id text,             -- Stripe transfer ID on success
  status reward_payout_status NOT NULL DEFAULT 'pending',
  error_message text,                  -- Error details on failure
  batch_date date NOT NULL,            -- Date payouts were prepared (e.g., '2026-02-28')
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- RLS: users can view their own payout history
ALTER TABLE public.reward_payouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own payouts"
  ON public.reward_payouts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
```

### Naming Convention

All currency amounts (`rate_per_point`, `currency_amount`) are in the currency's minor units, following Stripe API convention. The `currency` column alongside the amount makes the unit unambiguous.

## Phase 1: `prepare_monthly_payouts()`

PL/pgSQL function triggered by pg_cron on the last day of each month.

### Behavior

1. Fetch active exchange rate for the target currency
2. Query all `reward_wallets` with `balance > 0`
3. For each user:
   - If `payouts_enabled = true` → create `reward_payouts` record with `status = 'pending'`
   - If not ready → create record with `status = 'skipped'`, send reminder notification
4. Return summary (pending count, skipped count)

### Idempotency

Checks if payouts already exist for the current `batch_date`. If so, returns early without creating duplicates.

### Skipped Users

Wallet balance is preserved and carries over to next month.

## Phase 2: `execute-pending-payouts` Edge Function

Edge Function called via pg_net every 30 minutes.

### Behavior

1. Query `reward_payouts` where `status = 'pending'`
2. If no records, return immediately (no-op)
3. For each pending payout:
   - Call `stripe.transfers.create()` with **idempotency key** (based on `payout.id`)
   - On success: update `status = 'success'`, store `stripe_transfer_id`, deduct wallet balance via `deduct_reward_for_payout()` RPC
   - On failure: update `status = 'failed'`, store error message, send FCM notification to user. Wallet balance is NOT deducted.

### Why synchronous (not webhook-driven)?

Stripe transfers are **synchronous** — `stripe.transfers.create()` succeeds or throws immediately. There is no async settlement like PaymentIntents. The API response IS the final result. Using a **Stripe idempotency key** (keyed on `payout.id`) prevents double transfers if the Edge Function retries the same payout.

### Timeout Handling

Phase 2 runs every 30 minutes. If it times out mid-batch, remaining `pending` records are processed on the next invocation. The idempotency key ensures no double transfers for records that were partially processed.

## `deduct_reward_for_payout()` RPC

Atomic function called after a successful Stripe transfer:

- Deducts `points_amount` from `reward_wallets.balance`
- Inserts a `reward_ledger` entry with `reason = 'payout'` and negative amount
- Raises exception if insufficient balance (safety check — should not happen in normal flow)

## Cron Scheduling

```sql
-- Phase 1: Last day of month at 00:00 JST (15:00 UTC previous day)
-- Runs on 28-31 with internal guard for actual last day
SELECT cron.schedule(
  'prepare-monthly-payouts',
  '0 15 28-31 * *',
  $$SELECT public.prepare_monthly_payouts('JPY')$$
);

-- Phase 2: Every 30 minutes (no-op when no pending records)
SELECT cron.schedule(
  'execute-pending-payouts',
  '*/30 * * * *',
  $$SELECT net.http_post(...)$$
);
```

## Stripe Connect Integration

### Transfer Creation

```typescript
const transfer = await stripe.transfers.create({
  amount: payout.currency_amount,
  currency: payout.currency.toLowerCase(),
  destination: connectAccountId,
  description: `Peppercheck reward payout - ${payout.points_amount} points`,
  metadata: {
    payout_id: payout.id,
    user_id: payout.user_id,
  },
}, {
  idempotencyKey: `payout-${payout.id}`,
});
```

### Fee Structure

- **Transfers** (platform → connected account): No fee
- **Payouts** (connected account → bank): Handled automatically by Stripe for Express accounts

### Account Status

`payouts_enabled` is owned by Stripe webhooks (`account.updated`), not by payout results. A transfer failure does NOT change `payouts_enabled`.

## Notifications

| Event | Notification |
|---|---|
| Skipped (no Connect) | "Complete payout setup to receive your rewards" |
| Failed (transfer error) | "Payout failed, please check your account settings" |
| Success | No notification in MVP (user sees balance change in app) |

Notifications use the existing FCM push notification pattern (call send-notification Edge Function directly).

## Error Handling

- **No minimum payout threshold**: Any balance > 0 is eligible for payout
- **Failed transfers**: Wallet balance preserved, retry next month automatically
- **Insufficient platform balance**: Payout fails, classified same as other failures for MVP
- **Refined failure classification**: Follow-up issue

## Follow-up Issues

1. **Admin payout reporting**: Dashboard showing success/failure rates, monthly totals, batch summaries
2. **Refined failure classification**: Distinguish user-fault (account issue) vs system-fault (platform balance)
3. **Success notification**: Optional push notification when payout completes

## Artifacts Summary

| Type | Name | Purpose |
|---|---|---|
| Table | `reward_exchange_rates` | Configurable point-to-currency rates |
| Table | `reward_payouts` | Audit trail for payout attempts |
| Enum | `reward_payout_status` | pending/success/failed/skipped |
| Function | `prepare_monthly_payouts()` | Phase 1: create payout records |
| Function | `deduct_reward_for_payout()` | Deduct wallet after successful transfer |
| Edge Function | `execute-pending-payouts` | Phase 2: Stripe transfers |
| Cron | `prepare-monthly-payouts` | Monthly trigger for Phase 1 |
| Cron | `execute-pending-payouts` | Every 30 min trigger for Phase 2 |
| RLS Policy | `reward_payouts` SELECT | Users can view own payout history |
| Notification templates | payout_skipped, payout_failed | FCM push notifications |
