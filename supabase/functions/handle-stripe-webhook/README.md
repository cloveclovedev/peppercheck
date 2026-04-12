# handle-stripe-webhook Edge Function

Handles incoming Stripe webhook events and syncs relevant data to the database.

## Supported Events

| Event | Handler | Purpose |
|-------|---------|---------|
| `checkout.session.completed` | `handleSubscriptionChange` | Sync subscription on initial checkout |
| `customer.subscription.updated` | `handleSubscriptionChange` | Sync subscription status changes |
| `customer.subscription.deleted` | `handleSubscriptionChange` | Sync subscription cancellation |
| `invoice.payment_succeeded` | `handleInvoicePaymentSucceeded` | Reset monthly points on renewal |
| `account.updated` | `handleAccountUpdated` | Sync Connect account onboarding status |

## Local Testing

### Prerequisites

- Supabase local environment running (`supabase start`)
- [Stripe CLI](https://docs.stripe.com/stripe-cli) installed and authenticated (`stripe login`)
- Edge Functions served locally (`supabase functions serve`)

### Testing account.updated

1. **Set up test data** — Run `supabase/snippets/setup_stripe_account_webhook_test.sql` in the SQL Editor (http://127.0.0.1:54323), replacing placeholder IDs with real values.

2. **Start webhook listener** (terminal 1):
   ```bash
   stripe listen --forward-to http://127.0.0.1:54321/functions/v1/handle-stripe-webhook
   ```
   Copy the webhook signing secret (`whsec_...`) and set it in `.env.local` or via `supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...`.

3. **Trigger event** (terminal 2):
   ```bash
   stripe trigger account.updated
   ```

4. **Verify** — Run the verification query from the snippet. `charges_enabled` / `payouts_enabled` / `connect_requirements` should be updated, and `updated_at` should reflect the current time.

> **Note:** `stripe trigger account.updated` sends a generic test event. The `account.id` in the test event won't match your local test data unless you use a real Connect account from Stripe test mode. For full E2E testing, complete the payout setup flow in the app against Stripe test mode, then the real `account.updated` webhook will fire with the correct account ID.

## Stripe Dashboard Configuration

Register this endpoint in Stripe Dashboard → Developers → Webhooks:

1. **Endpoint URL:** `https://<project>.supabase.co/functions/v1/handle-stripe-webhook`
2. **Events from your account:** `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`
3. **Events from Connected accounts:** `account.updated`
4. Copy the signing secret → set as `STRIPE_WEBHOOK_SECRET` in Edge Function environment

## Unit Tests

Run existing unit tests:

```bash
cd supabase/functions/handle-stripe-webhook && deno test --allow-env --allow-net index_test.ts
```
