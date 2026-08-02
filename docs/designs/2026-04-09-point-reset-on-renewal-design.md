# Point Reset on Subscription Renewal

## Problem

The current `grant_subscription_points()` function **adds** the plan's monthly points on top of the existing balance on each renewal. For a Light Plan (5 pt/month) with 5-minute test renewals, this quickly accumulates to 200+ points.

The intended behavior is that points **reset** to the plan's allocated amount on each renewal, with no carryover of unused points. Unlimited accumulation risks scenarios where a burst of task requests concentrates on a limited referee pool with no natural throttle.

## Design

### Rename and Rewrite SQL Function

Replace `grant_subscription_points` with `reset_subscription_points`.

**Signature** (unchanged):

```sql
reset_subscription_points(
  p_user_id uuid,
  p_amount integer,
  p_invoice_id text
) RETURNS boolean
```

**Reset logic:**

```sql
-- Read current state
SELECT balance, locked INTO v_old_balance, v_old_locked
FROM public.point_wallets
WHERE user_id = p_user_id;

-- Reset: new balance = plan amount + locked (preserve in-flight matches)
UPDATE public.point_wallets
SET balance = p_amount + v_old_locked,
    updated_at = now()
WHERE user_id = p_user_id;
```

Locked points (reserved for in-progress matches) are preserved. The `CHECK (balance >= locked)` constraint is always satisfied because `balance = p_amount + locked >= locked`.

**Ledger recording:**

Each reset produces up to two ledger entries:

1. **Expiry entry** (only if unused points > 0): Records the forfeited points as a negative amount with reason `plan_renewal_expiry`.
   - Amount: `-(v_old_balance - v_old_locked)` (the available points that are being forfeited)
2. **Renewal entry**: Records the new plan allocation as a positive amount with reason `plan_renewal`.
   - Amount: `p_amount`

When no available points exist to forfeit (`v_old_balance - v_old_locked = 0`), only the renewal entry is written.

**Idempotency**: Unchanged. Checks `point_ledger` for existing `plan_renewal` entry with matching description before proceeding.

**New wallet fallback**: Unchanged. If no wallet exists, creates one with `balance = p_amount`.

### Enum Addition

Add `plan_renewal_expiry` to the `point_reason` enum type for the expiry ledger entries.

### Edge Function Changes

Both handlers call the renamed RPC:

- **handle-google-play-rtdn/index.ts**: `rpc('grant_subscription_points', ...)` → `rpc('reset_subscription_points', ...)`
- **handle-stripe-webhook/index.ts**: Same rename.

No logic changes in the edge functions. Parameters and idempotency keys remain identical.

### Schema File Changes

- Delete `supabase/schemas/point/functions/grant_subscription_points.sql`
- Create `supabase/schemas/point/functions/reset_subscription_points.sql`
- Update `supabase/config.toml` to reference the new file

### Terms of Service Update

Add the following to the Subscription section in `peppercheck-webapp/messages/en.json` (and `ja.json`):

- Points reset to the plan's allocated amount on each renewal date
- Unused points do not carry over to the next billing period
- Points reserved for in-progress matches are preserved through renewal

### Test Plan

pgTAP unit tests in `supabase/tests/database/reset_subscription_points.test.sql`:

| Scenario | Expected |
|---|---|
| Remaining available points > 0 | Balance resets to `p_amount + locked`; expiry ledger entry recorded |
| Remaining available points = 0 | Balance resets to `p_amount + locked`; no expiry entry |
| Locked points > 0 | Locked preserved; `balance = p_amount + locked` |
| Idempotency (same invoice_id twice) | Second call returns false, no balance change |
| Ledger entries | Expiry (negative) + renewal (positive) entries with correct amounts and reasons |
| New wallet (no existing row) | Wallet created with `balance = p_amount` |
