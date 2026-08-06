# Deployment Flow Design

## Overview

Automated CI/CD pipeline for peppercheck, covering Supabase (DB migrations + Edge Functions), Flutter Android (Firebase App Distribution + Google Play Store), and Webapp (Next.js on Cloudflare Workers).

## Branch Strategy: Release Branch Model

```
main (always latest, no deploy on push)
  |
  +-- beta/v0.3 (cut from main when release is near)
  |     +-- push -> auto-deploy to all beta environments
  |     +-- v0.3.0 tag -> auto-deploy to all production environments
  |
  +-- hotfix flow:
        1. fix PR -> main (squash merge)
        2. cherry-pick to beta/v0.3
        3. v0.3.1 tag on beta/v0.3
```

### Branch Naming

- Feature: `feat/<description>` -> PR to `main`
- Beta release: `beta/v0.x` -> cut from main
- Release tag: `v0.x.y` -> created on `beta/v0.x`
- Hotfix: `fix/<description>` -> PR to `main` -> cherry-pick to `beta/v0.x`

## Trigger Mapping

| Trigger | Condition | Action |
|---------|-----------|--------|
| PR to `main` | `peppercheck_flutter/**` changed | Flutter analyze + test |
| PR to `main` | `supabase/migrations/**` changed | Supabase DB test + data check + dry-run |
| PR to `main` | `peppercheck-webapp/**` changed | Webapp type-check + lint + prettier |
| Push to `beta/v*` | always | Deploy all components to beta |
| `v*` tag | always | Deploy all components to production |

## Deploy Order

```
1. Supabase DB migrations (supabase db push)
2. Supabase Edge Functions (supabase functions deploy --use-api)
3. Flutter Android build + distribute  (parallel, after Supabase)
4. Webapp deploy (Cloudflare Workers)   (parallel, after Supabase)
```

DB migrations run first because Edge Functions and apps may depend on schema changes. Flutter and Webapp deploy in parallel after Supabase completes.

## Component: Supabase

### Deploy Targets

| Environment | Project | Trigger |
|-------------|---------|---------|
| Local | `supabase start` | manual |
| Beta | beta Supabase project | Push to `beta/v*` |
| Production | production Supabase project | `v*` tag |

### Deploy Steps

```bash
supabase link --project-ref $PROJECT_ID    # connect to target project
supabase db push                            # apply pending migrations
supabase functions deploy --use-api         # deploy all Edge Functions (no Docker)
```

### Edge Function Secrets

Runtime secrets (STRIPE_SECRET_KEY, etc.) are set per environment via CLI:

```bash
supabase secrets set --project-ref <id> --env-file .env.beta
supabase secrets set --project-ref <id> --env-file .env.production
```

These rarely change and are managed manually, not via CI/CD.

### Production Safety

- Beta environment is always deployed first (validated before production)
- `supabase db push --dry-run` runs in PR CI for migration changes
- Migrations use `IF EXISTS`/`IF NOT EXISTS` guards
- Large table changes set `SET lock_timeout = '10s'`
- Destructive changes (column drops) are done in 2 phases across releases
- Rollback is forward-only: create a new "undo" migration

### config.toml Management

Out of scope for initial implementation. Auth/API settings managed via Dashboard for now. Tracked as separate GitHub issue for future declarative management via `supabase config push` or Terraform.

## Component: Flutter Android

### Deploy Targets

| Environment | Build | Entry Point | Distribution |
|-------------|-------|-------------|-------------|
| Beta | APK (release) | `lib/main_staging.dart` | Firebase App Distribution |
| Production | AAB (release) | `lib/main_production.dart` | Google Play Store (future) |

### Build Environment

- Runner: `ubuntu-latest` (1x minute rate)
- Java: Temurin 17
- Flutter: 3.38.3 (stable)
- Caching: Flutter SDK + pub packages (`subosito/flutter-action` cache) + Gradle (`gradle/actions/setup-gradle`)

### Android Signing in CI

1. Keystore file encoded as Base64 and stored in GitHub Secrets
2. Decoded at build time and `key.properties` generated

### Firebase App Distribution (beta)

Uses Firebase CLI (official Google tool) directly:

```bash
firebase appdistribution:distribute <apk-path> \
  --app $FIREBASE_APP_ID \
  --groups internal-testers
```

Authentication via `google-github-actions/auth@v2` (Google official).

### Google Play Store (production, future)

Decision deferred until first manual AAB upload is completed. Options: `r0adkll/upload-google-play` action or Fastlane `supply`.

### Cost Estimate

| Step | Duration |
|------|----------|
| Setup (checkout, Java, Flutter, Gradle) | ~2min |
| pub get + analyze + test | ~2-3min |
| Build APK/AAB | ~3-5min |
| Distribute | ~1min |
| **Total (cached)** | **~7-10min** |

Estimated monthly usage: ~350min (well within 2,000min free tier).

## Component: Webapp (Next.js on Cloudflare Workers)

### Deploy Targets

| Environment | Wrangler Env | Domain | Trigger |
|-------------|-------------|--------|---------|
| Beta | `staging` | `*.workers.dev` | Push to `beta/v*` |
| Production | `production` | `peppercheck.dev` | `v*` tag |

### Wrangler Environment Config

Add `env` sections to `wrangler.jsonc`:

```jsonc
{
  "env": {
    "staging": {
      "workers_dev": true,
      "vars": { "NEXTJS_ENV": "staging" }
    },
    "production": {
      "routes": [{ "pattern": "peppercheck.dev/*", "zone_name": "peppercheck.dev" }],
      "vars": { "NEXTJS_ENV": "production" }
    }
  }
}
```

### Deploy Commands

```bash
# Beta
opennextjs-cloudflare build && opennextjs-cloudflare deploy -- --env staging

# Production
opennextjs-cloudflare build && opennextjs-cloudflare deploy -- --env production
```

Uses `cloudflare/wrangler-action@v3` (Cloudflare official).

## Workflow File Structure

```
.github/workflows/
├── ci-flutter.yml          # PR: Flutter analyze + test
├── ci-supabase.yml         # PR: DB test + data check + dry-run
├── ci-webapp.yml           # PR: type-check + lint + prettier (renamed)
├── deploy-beta.yml         # beta/v* push: all components to beta
└── deploy-production.yml   # v* tag: all components to production
```

### ci-supabase.yml

Consolidates migration testing and data integrity checks into a single workflow to share the Supabase setup cost:

1. `supabase start` (shared setup, ~1-2min)
2. `supabase test db` (unit tests)
3. Data integrity check (CSV validation)
4. `supabase db push --dry-run` (migration preview)

Triggered only when `supabase/migrations/**` changes.

### deploy-beta.yml / deploy-production.yml

Job dependency graph:

```
supabase-deploy
    +-- flutter-build-distribute (needs: supabase-deploy)
    +-- webapp-deploy (needs: supabase-deploy)
```

All workflows use `concurrency` to cancel superseded runs:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI authentication |
| `BETA_SUPABASE_PROJECT_ID` | Beta Supabase project ref |
| `BETA_SUPABASE_DB_PASSWORD` | Beta DB password |
| `PROD_SUPABASE_PROJECT_ID` | Production Supabase project ref |
| `PROD_SUPABASE_DB_PASSWORD` | Production DB password |
| `KEYSTORE_BASE64` | Base64-encoded Android keystore |
| `KEYSTORE_PASSWORD` | Keystore store password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Key alias |
| `FIREBASE_APP_ID` | Firebase App ID |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase service account JSON |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID |

## Out of Scope (tracked as GitHub Issues)

- iOS build + App Store deployment
- config.toml declarative management (Terraform / `supabase config push`)
- Edge Function unit tests (`deno test`)
- Google Play Store automated deployment (requires first manual upload)
- Stripe resource management via code
