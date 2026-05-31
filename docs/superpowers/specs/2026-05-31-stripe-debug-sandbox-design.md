# Stripe Debug Sandbox

**Date:** 2026-05-31
**Status:** Draft
**Issue:** #422 (parent: #418 multi-environment setup roadmap)
**Related:** #421 (stripe-cli setup runbook), #443 (dead Stripe subscription code cleanup)

## Goal

Create a dedicated Stripe sandbox for local debug development so that operator-local Stripe Connect / payout work no longer shares state with the staging sandbox wired to BETA Supabase. Standardize secret placement and Stripe CLI profile usage so the setup is reproducible.

## Why

The existing Stripe sandbox is wired to BETA Supabase as the staging webhook destination and is simultaneously used by the operator for local `stripe listen` forwarding. Events triggered from the operator's machine reach the BETA Supabase Edge Function, mixing local-debug noise with staging signal. This blocks confident staging-side validation of Stripe Connect / payout flows.

This change isolates local debug into its own sandbox without touching staging-side secrets, deploy workflows, or the existing sandbox's webhook endpoint registration.

## Use case for the debug sandbox

Stripe Connect / payout local development:

- `payout-setup` Edge Function (creates Connect Express accounts, generates onboarding link)
- `execute-pending-payouts` Edge Function (creates Transfers / Payouts against Connect accounts)
- `handle-stripe-webhook` Edge Function (signature verification + processing of `account.updated`, `payout.failed`, etc.)

Stripe Checkout / subscription is out of scope — PepperCheck's subscription is IAP-only and Stripe-based subscription code paths are dead (tracked in #443).

## Sandbox topology

| Environment | Stripe mode | Webhook destination | Operator's stripe-cli profile |
|---|---|---|---|
| production | live | PROD Supabase `handle-stripe-webhook` (URL registered on live) | `peppercheck-live` (optional, read-only inspection) |
| staging | existing sandbox | BETA Supabase `handle-stripe-webhook` (URL registered on the sandbox) | `peppercheck-staging` (optional, inspection only) |
| debug | new sandbox | none registered; `stripe listen --forward-to localhost:54321/...` only | `peppercheck-debug` (**required**) |

Existing wiring for production and staging is unchanged. No secret rotation on the deploy side.

## Stripe CLI profile naming

CLI profile names follow Stripe's own vocabulary ("live") rather than PepperCheck's internal `production` term, since the consumer (`stripe` CLI) names the concept "live mode":

- `peppercheck-debug` — **required** for `stripe listen` against the new debug sandbox
- `peppercheck-staging` — optional, only when inspecting the staging sandbox via CLI
- `peppercheck-live` — optional, read-only inspection of live data

This PR only sets up `peppercheck-debug`. Setup commands for the other two profiles are documented for future operator reference but not executed as part of this PR.

## Secret placement

| File | Key | Consumer |
|---|---|---|
| `supabase/functions/.env` | `STRIPE_SECRET_KEY=sk_test_<debug>` | local Edge Function calls to Stripe API |
| `supabase/functions/.env` | `STRIPE_WEBHOOK_SECRET=whsec_<stripe-listen>` | `handle-stripe-webhook` signature verification |
| `~/.config/stripe/config.toml` | `[peppercheck-debug]` profile | `stripe` CLI commands |

All target files are gitignored. The script never prints secret values to stdout and never writes them to a tracked file.

Notably **not** updated by this PR:

- `peppercheck_flutter/assets/env/.env.debug` — `STRIPE_PUBLISHABLE_KEY` is left empty. The Flutter `flutter_stripe` integration is dead under the IAP-only policy and is scheduled for removal in #443.
- `stripe/.env` — `sync-prices.ts` is dead under the IAP-only policy and is scheduled for removal in #443.
- `supabase/.env` — does not contain Stripe keys; Stripe lives at `supabase/functions/.env`.

## Webhook signing secret strategy

`stripe listen` generates a webhook signing secret that **is stable across command restarts** for a given CLI profile (per Stripe CLI documentation: "This process generates a webhook signing secret that remains consistent across command restarts"). Therefore:

- No webhook endpoint registration is needed in the debug sandbox's Dashboard.
- `stripe listen --project-name=peppercheck-debug --print-secret` is run once during setup, and the resulting `whsec_*` is written to `supabase/functions/.env` as `STRIPE_WEBHOOK_SECRET`.
- Subsequent `stripe listen --forward-to ...` runs reuse the same secret.

If the operator ever runs `stripe login` again under the `peppercheck-debug` profile, the secret may rotate; the script supports re-running to reconcile.

## Stripe Connect enablement

The new sandbox must have Stripe Connect enabled (Dashboard, one-time toggle) so that `payout-setup` can create Express accounts. Test Connect accounts are created on demand via the existing `payout-setup` Edge Function — no separate bootstrap script is needed.

## Script: `scripts/setup/configure-stripe-debug-sandbox.sh`

A bash script that automates the local-side configuration. It does **not** create the sandbox itself (no public Stripe API exists for that). It only handles the steps after the sandbox exists in the Dashboard.

### Behavior

1. **Preconditions check**: `stripe` CLI installed; required dirs exist.
2. **Prompt**: confirm the operator has created the sandbox in the Dashboard and noted the `sk_test_*` key. If not, print the Dashboard URL and exit. (The `pk_test_*` is not used by this PR — see "Secret placement" for the rationale.)
3. **CLI profile setup**: prompt for `sk_test_*` and pipe into `stripe login --project-name=peppercheck-debug --interactive`.
4. **Webhook secret retrieval**: run `stripe listen --project-name=peppercheck-debug --print-secret`, capture the `whsec_*`.
5. **`.env` upsert**: for each target key in each target file, replace the existing line if present or append if absent. Use tempfile + atomic `mv`. Never echo the secret value to stdout.
6. **Next-step hint**: print copy-pasteable commands for verification (`supabase functions serve`, `stripe listen --forward-to ...`, `stripe trigger account.updated`).

### Idempotency

Re-running the script with the same inputs produces the same `.env` content. Re-running with different inputs (e.g., after `stripe login` rotated the webhook secret) reconciles by replacing the existing line.

### Safety properties

- No secret value is printed to stdout or written to a tracked file.
- The script does not delete or touch any other `.env` keys.
- The script does not create or modify anything in the Stripe sandbox itself.

## File and example updates

### `supabase/functions/.env.example`

Already lists `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` — no change needed.

### `stripe/.env.example`

Currently `STRIPE_SECRET_KEY=sk_test_...`. Leave unchanged in this PR; #443 will remove the file when `sync-prices.ts` is deleted.

### `peppercheck_flutter/assets/env/.env.example`

Currently lists `STRIPE_PUBLISHABLE_KEY=pk_test_...`. Leave unchanged in this PR; #443 will remove the entry when the Flutter Stripe integration is dropped.

## Verification

Acceptance for this PR:

- The script runs to completion with the operator's input and writes the expected three updates (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` to `supabase/functions/.env`; `peppercheck-debug` profile to `~/.config/stripe/config.toml`).
- Running `stripe trigger account.updated --project-name=peppercheck-debug` with `stripe listen --project-name=peppercheck-debug --forward-to http://localhost:54321/functions/v1/handle-stripe-webhook` reaches the local Edge Function with a 200 response and signature verification passing (verify in `supabase functions serve` logs).
- `git diff` against staging-side secrets shows no change: no edit to `BETA_STRIPE_*` GitHub Secrets, no edit to the existing sandbox's registered webhook endpoint.
- The existing sandbox (now serving as staging) continues to deliver events to BETA Supabase after this change (regression check against a recent BETA event log).

## Out of scope

- **Stripe billing / Checkout / subscription rebuild** — IAP-only policy is in effect; Stripe-based subscription purchase is stopped. No `products` / `prices` seeding to the debug sandbox.
- **`developer-docs` runbook prose** — `developer-docs/.../stripe-cli-setup.adoc` is owned by #421. This spec defines the operator workflow that #421 will document; the prose itself lives there.
- **Sandbox creation automation** — no public Stripe API exists for creating sandboxes. The Dashboard step stays manual.
- **Test Connect account bootstrap script** — `payout-setup` is idempotent and works as the on-demand bootstrap path.
- **Staging sandbox rebuild** — existing sandbox is reused as staging; rotating BETA secrets is avoided.
- **Removing dead Stripe Checkout / subscription code** — tracked in #443.

## Future work

- #443 dead-code cleanup, once landed, allows this spec's "leave unchanged" notes on `.env.example` files and `stripe/` directory to be retired.
- #421 stripe-cli setup runbook will absorb the operator-facing prose for the workflow described here.
- If `peppercheck-staging` / `peppercheck-live` CLI profiles see real use, codify their setup in the same script behind a `--profile=<name>` flag.

## References

### Existing design docs

- `docs/superpowers/specs/2026-05-11-multi-environment-setup-roadmap-design.md` — the umbrella roadmap. Topology in this spec matches its `Stripe` row and "Webhook routing" subsection.
- `docs/superpowers/specs/2026-04-12-stripe-account-updated-webhook-design.md` — the webhook event this sandbox is used to test locally.

### External documentation

- [Stripe Sandboxes](https://docs.stripe.com/sandboxes)
- [Stripe CLI listen command](https://github.com/stripe/stripe-cli/wiki/Listen-command)
- [Stripe CLI login command](https://github.com/stripe/stripe-cli/wiki/Login-command)

### Project conventions

- `.claude/rules/edge-functions.md`
- `.claude/rules/supabase-workflow.md`

## Revision log

| Date | Change |
|---|---|
| 2026-05-31 | Initial draft. |
