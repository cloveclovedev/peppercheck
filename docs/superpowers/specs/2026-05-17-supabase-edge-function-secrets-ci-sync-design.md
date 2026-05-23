# Supabase Edge Function Secrets CI Sync — Design

- **Issue:** [#420](https://github.com/cloveclovedev/peppercheck/issues/420) — `chore(supabase): auto-set edge function secrets in CI deploy workflow`
- **Parent:** [#418](https://github.com/cloveclovedev/peppercheck/issues/418) — multi-environment setup roadmap, Phase 0 / task 0.2
- **Status:** Design accepted, pending implementation plan

## Goal

Edge Function runtime secrets are reconciled to a CI-controlled source of truth on every deploy. Operators stop maintaining Supabase project secrets by hand, and per-environment secrets follow the same `BETA_*` / `PROD_*` naming convention as the rest of the deploy workflow.

This change also takes the opportunity to tidy a handful of confusing env var names while we are formalizing the secret list, so the documentation (Phase 0 task 0.3) can describe the final names from day one.

## Motivation

Through v1.0.0, Edge Function secrets were set ad-hoc via `supabase secrets set` on the operator's laptop or via the Supabase Dashboard. That worked while production was the only target for side-effecting integrations (Stripe, FCM, R2, Google Play RTDN), but it creates three problems as the multi-environment split begins:

1. **Drift between projects.** No mechanism guarantees the BETA Supabase project has the same secret keys present as PROD, and there is no way to audit "what is set where" except by reading the dashboard.
2. **Onboarding / disaster recovery.** Reproducing a Supabase project from scratch requires a runbook that does not exist; the only authoritative copy of the values lives in the dashboard.
3. **Rotation burden.** Each secret rotation requires touching both GitHub (for any consumer that reads from `${{ secrets.* }}`) and the Supabase Dashboard. Forgetting one creates a silent break.

GitHub Secrets is the natural single source of truth: it is already where the deploy workflow reads everything else from, it has an audit log, and it can be edited from one UI.

## Approach

### Source of truth: GitHub Secrets, reconciled on every deploy

Both `deploy-beta.yml` and `deploy-production.yml` gain a step that runs `supabase secrets set --project-ref <env> --env-file <generated-env-file>` before `supabase functions deploy`. The env-file is generated inline in the workflow from `${{ secrets.* }}` values. The step is idempotent — running it on a project whose secrets already match GitHub Secrets is a no-op from a behavior standpoint.

Considered and rejected: **manual / status quo** (drift returns the moment a second environment is added), and **explicit `workflow_dispatch`-only sync job** (re-introduces the "did I remember to sync?" problem the change is meant to remove).

One-off updates via the Supabase Dashboard remain acceptable for emergencies. The next CI deploy will reconcile state back to whatever is in GitHub Secrets. Operations doc (Phase 0 task 0.3, issue #421) will spell out the rule: "if you change a secret on the dashboard for an emergency fix, mirror the value into GitHub Secrets before the next tag."

### Pre-check: hard fail on missing secrets

`${{ secrets.MISSING }}` evaluates to an empty string in GitHub Actions rather than erroring. Without a guard, a misconfigured GitHub Secret would silently overwrite a working Supabase secret with an empty value and break the deploy.

The workflow gets a pre-step that scans the required-secrets list and exits non-zero if any value is empty, listing the missing names. This means the very first run after this PR merges only succeeds once the operator has populated all `BETA_*` / `PROD_*` secrets via `scripts/setup-github-secrets.sh`.

### Naming convention: `BETA_*` and `PROD_*` everywhere

All env-specific secrets get both `BETA_*` and `PROD_*` keys in GitHub Secrets. Where a value is not yet split per environment (e.g. Google Play / Pub/Sub config for the BETA project, which has no production traffic yet), the operator copies the production value into the BETA key initially. Phase 2 (issue #430) will replace the BETA copy with a real staging-specific value when the staging RTDN topic is created.

`BETA_` (rather than `STAGING_`) matches the existing convention used by `BETA_SUPABASE_PROJECT_ID`, `BETA_STRIPE_PUBLISHABLE_KEY`, etc., and ties to the `beta/v*` branch naming. A rename to `STAGING_` is out of scope.

`CLOUDFLARE_ACCOUNT_ID` stays unprefixed because the Cloudflare account is shared across all environments.

### Env-file is generated to `/tmp`, never to the working tree

To avoid any chance of accidentally checking in a real-value env-file, the workflow writes the generated file to `/tmp/edge-functions.env` rather than into the repository directory. The runner is ephemeral, so cleanup is automatic.

### Step ordering

```
checkout
  → install supabase CLI
  → supabase link --project-ref <env>
  → supabase db push
  → [pre-check] required secrets non-empty
  → [generate] /tmp/edge-functions.env from ${{ secrets.* }}
  → supabase secrets set --project-ref <env> --env-file /tmp/edge-functions.env
  → supabase functions deploy --project-ref <env> --use-api
```

Secrets are set before functions are deployed, so a freshly deployed function never boots with stale-or-missing secrets.

### No prune

`supabase secrets set --env-file` is additive: keys present in the file are upserted, keys absent from the file are left untouched. We rely on this — the BETA Supabase project may have stale or experimental secrets the operator set via the dashboard and forgot. We do not delete them automatically. The operations doc (Phase 0 task 0.3) describes manual cleanup.

### Reusable workflow: deferred

The two deploy workflows will end up with two near-identical secret-sync blocks differing only in env prefix. Factoring this into a reusable workflow under `.github/workflows/_set-supabase-secrets.yml` is reasonable but is left as a future refactor — the existing two workflows already have many parallel blocks (Flutter env file generation, webapp env, etc.), and a one-off DRY pass over just this block would be inconsistent.

## Env var renames

While formalizing the secret list, four naming problems get fixed in this PR. Each is a small, isolated change.

### `STRIPE_ONBOARDING_RETURN_URL` / `STRIPE_ONBOARDING_REFRESH_URL` → removed

`payout-setup/index.ts` currently reads two full URLs from env and passes them directly to `stripe.accountLinks.create`. The URL path structure is determined by the webapp's routing, not by ops config, so it does not belong in a secret.

Replacement: introduce `WEB_BASE_URL` (see below), and construct the URLs in code:

```ts
const webBaseUrl = Deno.env.get("WEB_BASE_URL") ?? ""
// ...
refresh_url: `${webBaseUrl}/stripe/connect/refresh`,
return_url:  `${webBaseUrl}/stripe/connect/return`,
```

Net effect: two GitHub Secrets are deleted (per env), one new one (`*_WEB_BASE_URL`) is added, the URL path structure becomes version-controlled.

### `FIREBASE_SERVICE_ACCOUNT` → `FIREBASE_SERVICE_ACCOUNT_JSON`

Used by `send-notification/index.ts` for FCM push notifications. The current name does not communicate that the value is a JSON blob, and the parallel GitHub Secret used on the Flutter side (`FIREBASE_SERVICE_ACCOUNT_JSON`, for `firebase appdistribution:distribute`) already uses the `_JSON` suffix. Renaming the edge-function side aligns the two symbols.

The Flutter-side GitHub Secret `FIREBASE_SERVICE_ACCOUNT_JSON` (unprefixed) stays as-is for now. Phase 1 (issue #425) will split it into per-env service accounts when the staging / debug Firebase projects exist. For this PR, the operator can copy the same value into `BETA_FIREBASE_SERVICE_ACCOUNT_JSON` and `PROD_FIREBASE_SERVICE_ACCOUNT_JSON` if the same Firebase Admin SDK service account is currently used for both FCM and App Distribution.

### `OPERATOR_API_SECRET` → `OPERATOR_AUTH_TOKEN`

Used by `recommend-payout-topup/index.ts` to authenticate the operator's external task-management tool against the `X-Operator-Secret` header. The current name says nothing about which function, which header, or what role.

The new name reflects the role ("operator-only endpoint auth"), not the function. If additional operator-only endpoints are added later, they can share the same token or branch off — but for now there is only one consumer.

The HTTP header (`X-Operator-Secret`) is **not** renamed in this PR; doing so would require updating the operator's external caller in lockstep. The header name and the env var name divergence is acceptable.

### New: `WEB_BASE_URL`

Per-environment base URL of the webapp (e.g. `https://peppercheck.dev`, `https://staging.peppercheck.dev`). Replaces `STRIPE_ONBOARDING_*` for `payout-setup`. Lives in GitHub Secrets despite not being a "real" secret because:

- It is env-specific, so it has to come from somewhere env-specific
- The existing workflow has no other mechanism for env-specific non-secret config
- Adding `${{ vars.* }}` adoption just for this one value would be inconsistent

### Already in use but missing from `.env.example`

While auditing, we noticed two values currently set manually in the production Supabase project but missing from `supabase/functions/.env.example`:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — used by `handle-google-play-rtdn` for the Google Play Developer API
- `GOOGLE_PUBSUB_AUDIENCE`, `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL` — used by `handle-google-play-rtdn` for OIDC validation of incoming Pub/Sub push messages

This PR adds them to `.env.example` and the CI workflow secret list so that going forward they cannot quietly drift. The BETA values are seeded as copies of PROD for now; Phase 2 (issue #430) replaces them with staging-specific values when the staging RTDN topic exists.

## Naming summary

| Old name | New name | Source | Notes |
|---|---|---|---|
| `STRIPE_ONBOARDING_RETURN_URL` | _removed_ | — | constructed from `WEB_BASE_URL` in code |
| `STRIPE_ONBOARDING_REFRESH_URL` | _removed_ | — | constructed from `WEB_BASE_URL` in code |
| `FIREBASE_SERVICE_ACCOUNT` | `FIREBASE_SERVICE_ACCOUNT_JSON` | `BETA_*` / `PROD_*` | aligns with Flutter-side name |
| `OPERATOR_API_SECRET` | `OPERATOR_AUTH_TOKEN` | `BETA_*` / `PROD_*` | header `X-Operator-Secret` unchanged |
| _(new)_ | `WEB_BASE_URL` | `BETA_*` / `PROD_*` | replaces `STRIPE_ONBOARDING_*` |
| _(new in `.env.example`)_ | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | `BETA_*` / `PROD_*` | already in use in production |
| _(new in `.env.example`)_ | `GOOGLE_PUBSUB_AUDIENCE` | `BETA_*` / `PROD_*` | already in use in production |
| _(new in `.env.example`)_ | `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL` | `BETA_*` / `PROD_*` | already in use in production |

## Full secret list (both envs)

Generated env-file contents (BETA example; PROD substitutes `BETA_` → `PROD_`):

```
STRIPE_SECRET_KEY=${{ secrets.BETA_STRIPE_SECRET_KEY }}
STRIPE_WEBHOOK_SECRET=${{ secrets.BETA_STRIPE_WEBHOOK_SECRET }}
R2_BUCKET_NAME=${{ secrets.BETA_R2_BUCKET_NAME }}
R2_ACCESS_KEY_ID=${{ secrets.BETA_R2_ACCESS_KEY_ID }}
R2_SECRET_ACCESS_KEY=${{ secrets.BETA_R2_SECRET_ACCESS_KEY }}
R2_PUBLIC_DOMAIN=${{ secrets.BETA_R2_PUBLIC_DOMAIN }}
CLOUDFLARE_ACCOUNT_ID=${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
FIREBASE_SERVICE_ACCOUNT_JSON=${{ secrets.BETA_FIREBASE_SERVICE_ACCOUNT_JSON }}
OPERATOR_AUTH_TOKEN=${{ secrets.BETA_OPERATOR_AUTH_TOKEN }}
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=${{ secrets.BETA_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
GOOGLE_PUBSUB_AUDIENCE=${{ secrets.BETA_GOOGLE_PUBSUB_AUDIENCE }}
GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL=${{ secrets.BETA_GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL }}
WEB_BASE_URL=${{ secrets.BETA_WEB_BASE_URL }}
```

## Files touched

### Workflows
- `.github/workflows/deploy-beta.yml` — add pre-check + secrets sync step
- `.github/workflows/deploy-production.yml` — add pre-check + secrets sync step

### Edge Function code
- `supabase/functions/payout-setup/index.ts` — drop `STRIPE_ONBOARDING_*`, read `WEB_BASE_URL`, build paths in code
- `supabase/functions/send-notification/index.ts` — rename `FIREBASE_SERVICE_ACCOUNT` → `FIREBASE_SERVICE_ACCOUNT_JSON` (2 lines)
- `supabase/functions/recommend-payout-topup/index.ts` — rename `OPERATOR_API_SECRET` → `OPERATOR_AUTH_TOKEN` (1 line)
- `supabase/functions/recommend-payout-topup/index_test.ts` — match the rename (~10 lines)
- `supabase/functions/.env.example` — reflect renames, add new keys

### Operator tooling
- `scripts/github-secrets.example` — add the text-secret entries (BETA_*, PROD_* for STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, R2_*, OPERATOR_AUTH_TOKEN, GOOGLE_PUBSUB_AUDIENCE, GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL, WEB_BASE_URL); add file-secret instructions for FIREBASE_SERVICE_ACCOUNT_JSON / GOOGLE_PLAY_SERVICE_ACCOUNT_JSON per env

### Out of scope
- Flutter-side `WEB_DASHBOARD_URL` rename / cleanup — filed as a separate issue
- Flutter-side Firebase service account split per env — Phase 1, issue #425
- Real staging RTDN topic + BETA-specific Pub/Sub config — Phase 2, issue #430
- Operations runbook for secret management — Phase 0 task 0.3, issue #421
- Renaming `X-Operator-Secret` HTTP header — would require coordinated change with the external operator caller
- Reusable workflow factoring for the secrets-sync block — future refactor

## Testing plan

1. **Unit:** `supabase/functions/recommend-payout-topup/index_test.ts` updated to use the new env var name; existing assertions pass unchanged.
2. **Local:** Boot `supabase functions serve` with the new env names and exercise `payout-setup` (Stripe Connect onboarding link generation), `send-notification` (Firebase Admin init), and `recommend-payout-topup` (constant-time header check) to confirm each function reads the renamed env var correctly.
3. **CI (BETA):** Push this PR's branch (or merge into a `beta/v*` branch) and confirm:
   - The pre-check step fails noisily if a secret is missing (verify by intentionally omitting one in a draft run)
   - With all secrets populated, the deploy completes
   - `supabase secrets list --project-ref <BETA>` reflects the expected list post-deploy
4. **CI (PROD):** Repeat for production via tag push, before cutting the next user-visible version.

## Operator pre-merge checklist

1. Update local `scripts/github-secrets` (private, gitignored) with new entries from the updated `.example`
2. Run `./scripts/setup-github-secrets.sh` to push the text entries to GitHub Secrets
3. Set the binary/file secrets manually per the instructions added to `.example`:
   - `BETA_FIREBASE_SERVICE_ACCOUNT_JSON`, `PROD_FIREBASE_SERVICE_ACCOUNT_JSON`
   - `BETA_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `PROD_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
4. Verify with `gh secret list` that the workflow's required-secrets list is fully covered
5. Merge the PR; the next push to `beta/v*` will reconcile BETA, the next tag will reconcile PROD

## Open questions

None at design time. Will revisit if anything surfaces during implementation.
