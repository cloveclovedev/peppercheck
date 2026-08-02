# Stripe account.updated Webhook Design

- **Issue**: #345
- **Date**: 2026-04-12
- **Status**: Draft

## Problem

`stripe_accounts.payouts_enabled` / `charges_enabled` / `connect_requirements` are only updated when the user explicitly calls the `payout-setup` Edge Function. After completing Stripe Connect onboarding in the external browser, the user returns to the app but the DB still reflects the pre-onboarding state. The only way to sync is to call `payout-setup` again, which is unnatural UX.

## Solution

Add an `account.updated` event handler to the existing `handle-stripe-webhook` Edge Function. Stripe sends this event whenever a Connect account's status changes (e.g., onboarding completion, bank verification). The handler syncs the relevant fields to `stripe_accounts` automatically.

## Design

### Webhook Handler

Add `account.updated` case to the switch statement in `handle-stripe-webhook/index.ts`.

**Processing flow:**

1. Extract `account.id` from `event.data.object` (the Connect account ID, `acct_xxx`)
2. Query `stripe_accounts` by `stripe_connect_account_id`
3. If no matching row exists, log and return (payout-setup has not been called for this account)
4. Update `charges_enabled`, `payouts_enabled`, `connect_requirements` from the event payload

**Handler function signature:**

```typescript
async function handleAccountUpdated(
  event: Stripe.Event,
  supabaseAdmin: ReturnType<typeof createClient>,
)
```

**Key decisions:**

- **User lookup via DB, not Stripe metadata**: Query `stripe_accounts.stripe_connect_account_id` instead of relying on `account.metadata.profile_id`. More robust against metadata changes on Stripe side.
- **Single UPDATE query**: Use UPDATE with `.eq('stripe_connect_account_id', ...)` and check result rather than SELECT then UPDATE. One round-trip instead of two.
- **No Stripe API call needed**: The webhook event payload contains all necessary fields (`charges_enabled`, `payouts_enabled`, `requirements`), so no additional `stripe.accounts.retrieve()` is required.
- **No Flutter changes needed**: `PayoutController` already invalidates its provider on app resume, re-reading status from `stripe_accounts`. Once the webhook updates the DB, the existing Flutter code picks up the new state.

### Testing

No mock-based unit tests for this handler (cost vs. value is low for simple DB update logic). Instead:

- **Local integration test**: Use Stripe CLI (`stripe listen` + `stripe trigger`) against local Supabase
- **Test data**: SQL snippet in `supabase/snippets/` to insert a `stripe_accounts` row with a known `stripe_connect_account_id`
- **Test procedure**: Documented in `supabase/functions/handle-stripe-webhook/README.md`

### Stripe Dashboard Configuration

Register `account.updated` (Connected accounts) on the existing webhook endpoint. This is a manual step documented in the README.

## Files Changed

| File | Change |
|------|--------|
| `supabase/functions/handle-stripe-webhook/index.ts` | Add `account.updated` case and `handleAccountUpdated` function |
| `supabase/functions/handle-stripe-webhook/README.md` | New file. Local test procedure and Stripe Dashboard setup steps |
| `supabase/snippets/setup_stripe_account_test_data.sql` | New file. Insert test `stripe_accounts` row for webhook testing |

## Out of Scope

- Other webhook events (`payout.paid`, `payout.failed`, etc.)
- `developer-docs` reorganization
- Automated E2E test scripting
