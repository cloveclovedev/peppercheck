# Bitwarden Secrets Manager Development Injection

## Scope

Local development normally boots on non-sensitive dummy values in
`backend/.env` (copied from `backend/.env.example`). That's enough to build
and exercise most flows, but not ones that call a real external service —
today that's the Cloudflare R2 avatar upload/finalize flow.

`make up BWS_PROJECT_ID=<id>` injects real credential values from Bitwarden
Secrets Manager (`bws`) into the Compose stack for the duration of that one
run. This is optional: plain `make up` (no `BWS_PROJECT_ID`) keeps working
without it, exercising the avatar upload/finalize code path against a
nonexistent R2 account rather than a real bucket (see [#483][] — the shipped
dummy values don't currently make the api fail closed the way earlier docs in
this area assumed).

[#483]: https://github.com/cloveclovedev/peppercheck/issues/483

This repository shares the `development` Bitwarden Secrets Manager project
with other personal projects on the same free-tier account (capped at 3
projects and 3 machine accounts). The local machine account can read that
project only — it must never receive a staging or production access token.

## What goes through bws vs. what goes in `.env`

`backend/internal/core/config/config.go` classifies each R2 variable:

- **Real credentials** — `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`. These
  alone use the fail-closed `*_FILE` convention and are the only R2 values
  that go through `bws`.
- **Non-secret config** — `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_PUBLIC_DOMAIN`.
  Read with plain `os.Getenv`, same as `FIREBASE_PROJECT_ID`. These never go
  through `bws`; set real values directly in your own (gitignored) `.env`
  when you want to point at a real dev bucket.

`.env`'s "non-sensitive only" rule is about never writing a *real secret
value* into it — it's not exclusive to secrets. Non-secret config with a real
value is fine there, exactly like `FIREBASE_PROJECT_ID`.

## Secrets in bws

Create the following in the `development` project:

```text
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
```

These are deliberately **not** namespaced with a `PEPPERCHECK_`-style prefix:
they're a single Cloudflare R2 API token shared across this operator's
personal projects that use R2 for local dev, scoped to the buckets those
projects need. Rotate it once and every project sharing it picks up the new
value. A future dev secret that is genuinely peppercheck-specific (not meant
to be reused by another project) should still get a `PEPPERCHECK_` prefix to
avoid colliding with another project's secret name in this shared project.

Provisioning the underlying Cloudflare R2 token and the dev bucket(s) it can
reach, and populating these two values in Bitwarden, is a manual operator
step — not automated here.

Extend the bws secret set per phase as later features (Phase 4 private-R2
evidence, Phase 5 Stripe/RevenueCat, ...) introduce real dev-side credentials.

## Local setup

1. Install the native `bws` executable from the official Bitwarden Secrets
   Manager CLI release and place it on `PATH`.
2. Create (or reuse, if already set up for another project sharing this
   account) a read-only `local-development` machine account and grant it
   access to the `development` project only.
3. Store its access token in macOS Keychain with service name
   `bws-local-access-token` and your macOS account name. Do not put it in
   `.env`, shell startup files, Docker Compose files, or the repository. This
   Keychain entry is shared across every local repository that reads the same
   `development` project — there is only one token, not one per repository.
4. Set real, non-secret values for `R2_ACCOUNT_ID`, `R2_BUCKET`, and
   `R2_PUBLIC_DOMAIN` in `backend/.env` (see above — these don't go through
   bws).
5. Run:

   ```bash
   cd backend
   make up BWS_PROJECT_ID=<development-project-id>
   ```

   Find the `development` project's id with `bws project list` (it reads the
   same `BWS_ACCESS_TOKEN` described below):

   ```bash
   bws project list
   ```

## How it works

`make up BWS_PROJECT_ID=<id>` still creates `backend/.env` from the template
if missing, then runs `backend/scripts/bws-dev-up.sh <id>` instead of a plain
`docker compose up`. The script:

- Fails closed if `bws` isn't installed.
- Reads `BWS_ACCESS_TOKEN` from the `bws-local-access-token` Keychain item
  into its own process tree (falling back to an already-exported
  `BWS_ACCESS_TOKEN`, e.g. for a one-shot override), and fails closed if
  neither is available.
- Runs `bws run --project-id <id> -- docker compose up -d --build`. Only the
  selected project's secret values reach that one process tree; the BWS
  access token itself is never listed in Compose or passed to a container.

No compose.yaml mapping is needed: `bws run` sets `R2_ACCESS_KEY_ID` and
`R2_SECRET_ACCESS_KEY` directly in the process environment, and Docker
Compose resolves variables from the process environment before falling back
to `.env`, so those two values simply override the `.env` dummies for that
run. Every other variable — including the non-secret R2 config above — keeps
coming from `.env` either way, since bws never provides those.

## Out of scope

- Staging/production secret injection — already handled by the deploy
  pipeline (`scripts/ship-deployment.sh`, environment-scoped GitHub Actions
  secrets), which uses separate, dedicated staging/production BWS projects.
- CI — stays on `.env.example` dummies.
- Flutter-side secrets (Google OAuth, etc.) — live in the app build, handled
  separately.
