# Stripe Webhook Setup (notes)

## Endpoint
- Deploy URL: `/functions/v1/stripe-webhook` (Supabase Edge Functions)

## Events to subscribe
- `account.updated` — keep `charges_enabled` / `payouts_enabled` and requirements in sync.
- `setup_intent.succeeded` — update default payment method details.
- `payment_intent.succeeded` — finalize billing_jobs as succeeded.
- `payment_intent.payment_failed` — finalize billing_jobs as failed.
- `payout.paid` — payout created by payout-worker succeeded → finalize payout_jobs as succeeded.
- `payout.failed` — payout failed → finalize payout_jobs as failed.

Note: payout-worker now uses Stripe Payouts (from connected account balance to bank). `transfer.*` events are not required; subscribe to them only if you later switch back to Transfers.

## Stripe Dashboard steps
1. Developers → Webhooks → “Add endpoint”.
2. Set the environment-specific Edge Function URL, e.g. `https://<project>.functions.supabase.co/stripe-webhook`.
3. “Select events” and add the events listed above.
4. Copy the signing secret and set it as `STRIPE_WEBHOOK_SECRET` in the Edge Function environment.

## Local development
- Use Stripe CLI: `stripe listen --forward-to http://127.0.0.1:54321/functions/v1/stripe-webhook`.

## Notes
- finalize handlers rely on metadata `billing_job_id` / `payout_job_id`; if metadata is missing, the job will not be finalized.
