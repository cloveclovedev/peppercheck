# Confirm Reward Backend Design

## Context

Part of Issue #72 (Epic: Flutter Android MVP Features).
Follows `2026-02-14-confirm-judgement-design.md` which implemented the Confirm + Binary Rating flow.
This design adds the point consumption and referee reward mechanics triggered at Confirm time.

References:
- `developer-docs/modules/ROOT/examples/features/task/lifecycle.pu` — Task Lifecycle
- `developer-docs/modules/ROOT/pages/features/payment-and-reward.adoc` — Payment & Reward Flow

## Scope

**In scope:**
- Point lock mechanism (replace immediate consumption at task creation)
- Point settlement at Confirm time (approved / rejected)
- Referee reward wallet and ledger
- RLS policies for reward tables

**Out of scope:**
- Stripe Connect integration (referee bank payouts)
- Auto-Confirm (System Auto-Confirm after DueDate + N days)
- evidence_timeout settlement (future cron job)
- judgement_timeout point unlock (future cron job)
- Frontend/Flutter changes
- Currency conversion display

## Design Decisions

### Point Lock vs Immediate Consumption

**Decision: Lock at task creation, consume at Confirm.**

At task creation (`create_matching_request`), points are locked (reserved) but not consumed from the wallet balance. The actual consumption happens at Confirm time. This prevents points from being permanently lost in timeout scenarios where Taskers shouldn't be charged.

### Reward Unit

**Decision: Points (not currency).**

Referee rewards are tracked in points, same unit as Tasker consumption. Frontends can display estimated currency equivalents. This keeps the platform-internal accounting simple and allows future flexibility in reward rates.

### Reward Amount

**Decision: Same amount as Tasker consumption (1:1).**

No platform fee deduction at this stage. Tasker consumes N points → Referee receives N reward points.

### Reward Storage

**Decision: Separate `reward_wallets` table.**

Referee rewards are stored in a dedicated wallet, not shared with `point_wallets`. Reward points cannot be used to create tasks — they are payout-only.

### Timeout Rules

| Scenario | Tasker Points | Referee Reward |
|----------|--------------|----------------|
| Confirm (approved/rejected) | Consumed | Granted |
| evidence_timeout (Tasker's fault) | Consumed | Granted |
| judgement_timeout (Referee's fault) | Refunded (unlocked) | None |

Timeout processing will be implemented as separate cron jobs in future PRs.

## Schema Changes

### 1. `point_wallets` — Add `locked` column

```sql
ALTER TABLE point_wallets
    ADD COLUMN locked integer NOT NULL DEFAULT 0
    CONSTRAINT point_wallets_locked_non_negative CHECK (locked >= 0);

ALTER TABLE point_wallets
    ADD CONSTRAINT point_wallets_balance_gte_locked CHECK (balance >= locked);
```

Available points = `balance - locked`. Points are locked at task creation and either consumed (balance decreases, locked decreases) or unlocked (locked decreases only) at settlement.

### 2. `reward_wallets` — New table

```sql
CREATE TABLE reward_wallets (
    user_id uuid PRIMARY KEY REFERENCES profiles(id),
    balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
```

Stores the accumulated reward balance for Referees. Balance increases on review completion, decreases on payout.

### 3. `reward_ledger` — New table

```sql
CREATE TYPE reward_reason AS ENUM (
    'review_completed',   -- Reward for completing a review (Confirm)
    'evidence_timeout',   -- Reward when Tasker times out on evidence
    'payout',             -- Monthly payout to bank account
    'manual_adjustment'   -- Admin operation
);

CREATE TABLE reward_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES profiles(id),
    amount integer NOT NULL,
    reason reward_reason NOT NULL,
    description text,
    related_id uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);
```

`related_id` is a polymorphic UUID. The `reason` column provides context for what it refers to:
- `review_completed` → judgement_id
- `evidence_timeout` → judgement_id
- `payout` → payout batch ID (future)
- `manual_adjustment` → nullable

### 4. `point_reason` enum — Add new values

```sql
-- New values:
--   'matching_lock'    — Points locked at task creation
--   'matching_unlock'  — Points unlocked (returned) on timeout
--   'matching_settled' — Points consumed at Confirm
```

Existing `matching_request` remains for backward compatibility with existing ledger entries.

## Function Changes

### 1. `lock_points` — New function

Replaces `consume_points` in `create_matching_request`.

```
lock_points(p_user_id, p_amount, p_reason, p_description, p_related_id)
```

- Checks `balance - locked >= p_amount` (sufficient available points)
- Increments `point_wallets.locked`
- Inserts `point_ledger` entry with reason `matching_lock`
- Does NOT modify `balance`

### 2. `unlock_points` — New function

For future use by judgement_timeout cron job.

```
unlock_points(p_user_id, p_amount, p_reason, p_description, p_related_id)
```

- Decrements `point_wallets.locked`
- Inserts `point_ledger` entry with reason `matching_unlock`
- Does NOT modify `balance`

### 3. `consume_points` — Modified

Now settles locked points (deducts from both balance and locked).

```
consume_points(p_user_id, p_amount, p_reason, p_description, p_related_id)
```

- Decrements `point_wallets.balance` by `p_amount`
- Decrements `point_wallets.locked` by `p_amount`
- Inserts `point_ledger` entry

### 4. `grant_reward` — New function

Grants reward points to Referee.

```
grant_reward(p_user_id, p_amount, p_reason, p_description, p_related_id)
```

- Upserts `reward_wallets` (creates if not exists)
- Increments `reward_wallets.balance`
- Inserts `reward_ledger` entry

### 5. `confirm_judgement_and_rate_referee` — Extended

Adds point settlement and reward granting to the existing Confirm flow:

```
1. (existing) Validate caller is tasker
2. (existing) Validate judgement status is approved or rejected
3. (existing) Idempotency check
4. (new) Look up matching cost from task_referee_requests.matching_strategy
5. (new) consume_points(tasker_id, cost, 'matching_settled', ..., judgement_id)
6. (new) grant_reward(referee_id, cost, 'review_completed', ..., judgement_id)
7. (existing) Insert rating
8. (existing) Set is_confirmed = TRUE
```

All operations execute within a single transaction.

### 6. `create_matching_request` — Modified

Replace `consume_points` call with `lock_points`:

```
-- Before: PERFORM consume_points(v_user_id, v_cost, 'matching_request', ...)
-- After:  PERFORM lock_points(v_user_id, v_cost, 'matching_lock', ...)
```

### 7. `calculate_locked_points_by_active_tasks` — Review

This function calculates locked points by querying active requests. With the new `locked` column on `point_wallets`, this function may become redundant or serve as a consistency check. Keep for now.

## RLS Policies

### reward_wallets

```sql
-- Owner can read their own wallet
CREATE POLICY "Reward Wallets: select own" ON reward_wallets
FOR SELECT TO authenticated
USING (user_id = auth.uid());
```

No INSERT/UPDATE/DELETE policies — all mutations through SECURITY DEFINER functions.

### reward_ledger

```sql
-- Owner can read their own ledger entries
CREATE POLICY "Reward Ledger: select own" ON reward_ledger
FOR SELECT TO authenticated
USING (user_id = auth.uid());
```

No INSERT/UPDATE/DELETE policies — all mutations through SECURITY DEFINER functions.

## Existing Triggers — No Changes

The following triggers remain unchanged:
- `on_judgement_confirmed` — sends notification to referee
- `on_judgement_confirmed_close_request` — closes task_referee_request
- `on_all_requests_closed_close_task` — closes task when all requests closed

## Data Flow Summary

```
[Task Creation]
  Tasker → create_matching_request → lock_points
  point_wallets: locked += cost (balance unchanged)
  point_ledger: reason = 'matching_lock'

[Confirm (manual: approved/rejected)]
  Tasker → confirm_judgement_and_rate_referee
  → consume_points: balance -= cost, locked -= cost
  → grant_reward: reward_wallets.balance += cost
  → rating + is_confirmed + notification + close chain
  point_ledger: reason = 'matching_settled'
  reward_ledger: reason = 'review_completed'

[judgement_timeout (future cron)]
  → unlock_points: locked -= cost (balance unchanged)
  point_ledger: reason = 'matching_unlock'

[evidence_timeout (future cron)]
  → consume_points + grant_reward (same as Confirm)
  point_ledger: reason = 'matching_settled'
  reward_ledger: reason = 'evidence_timeout'
```

## Out of Scope (Future PRs)

- Stripe Connect payout integration
- Auto-Confirm system (DueDate + N days cron)
- evidence_timeout settlement cron
- judgement_timeout point unlock cron
- Currency conversion API for frontend display
- Payout history UI
