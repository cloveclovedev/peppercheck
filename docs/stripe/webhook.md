# Stripe Webhook Configuration

This document tracks how we configure Stripe webhooks for Peppercheck.

## Endpoint

- **Destination**: Supabase Edge Function `stripe-webhook`
  - URL (production): `https://<project>.functions.supabase.co/stripe-webhook`
- **Request authentication**: Stripe signing secret (`STRIPE_WEBHOOK_SECRET`) stored in Supabase function secrets.
- **JWT verification**: Disabled in `supabase/functions/config.toml` for `stripe-webhook`.

## Events

| Event                    | Purpose                                                          |
|-------------------------|------------------------------------------------------------------|
| `setup_intent.succeeded` | Triggered whenever a PaymentSheet Setup Intent completes. Used to cache the default payment method (brand / last4 / exp) into `stripe_accounts`. |

We do not currently subscribe to `setup_intent.canceled` or `payment_method.attached`. If future flows require them, expand the webhook accordingly.

## Stripe Dashboard Steps

1. Navigate to **Developers → Webhooks → +Add endpoint**.
2. Enter the Supabase Edge Function URL and select **Listen to events on your account**.
3. Choose API version `2025-10-29.clover` (or latest compatible).
4. Add the `setup_intent.succeeded` event.
5. Save and copy the **Signing secret**, set it as `STRIPE_WEBHOOK_SECRET` in Supabase (`supabase secrets set` or dashboard).

Keep this document updated whenever webhook endpoints or events change.
