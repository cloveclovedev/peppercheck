# Android Product Flavor Split + Android Firebase Per-Flavor Config

**Date:** 2026-06-05
**Status:** Draft
**Type:** Feature spec (Phase 1 of multi-environment roadmap)
**Parent:** [#418](https://github.com/cloveclovedev/peppercheck/issues/418)
**Implements:** [#423](https://github.com/cloveclovedev/peppercheck/issues/423) (expanded — see "Scope reshape" below)
**Requires merged:** [#445](https://github.com/cloveclovedev/peppercheck/issues/445) (debug → dev rename precursor)

## Goal

Introduce three Android product flavors (`dev` / `staging` / `production`) with distinct `applicationId` packages via `applicationIdSuffix`, inject each flavor's `google-services.json` at the Google-recommended per-source-set path, and add reusable bootstrap scripts that create two new Firebase projects (`peppercheck-dev`, `peppercheck-staging`) and download per-flavor Firebase config files.

After this PR's implementation merges:

- Three Android APKs / AABs with packages `dev.cloveclove.peppercheck`, `dev.cloveclove.peppercheck.staging`, `dev.cloveclove.peppercheck.dev` can be built independently.
- All three install side-by-side on a single device.
- Each running build registers FCM tokens to its environment's own Firebase project.
- Existing production (`v*` tag) and staging (`beta/v*` branch) CI deploys continue to function with no regression to the production deploy and with the staging deploy now pointing at the new `peppercheck-staging` Firebase project.

iOS-side per-flavor identity work remains in [#424](https://github.com/cloveclovedev/peppercheck/issues/424) (scheme + xcconfig) and reshaped [#425](https://github.com/cloveclovedev/peppercheck/issues/425) (Xcode plist wiring + APNs Auth Key upload). This spec pre-positions iOS Firebase config files at their planned paths so #424 / #425 do not need to re-run the bootstrap scripts.

## Why

The umbrella roadmap ([`2026-05-11-multi-environment-setup-roadmap-design.md`](2026-05-11-multi-environment-setup-roadmap-design.md)) sets out the motivation: existing PepperCheck deploys validate side-effect integrations (FCM push, IAP, Stripe payouts) directly in production because no isolated staging / debug surface exists. Phase 1 establishes per-flavor app identity and per-environment Firebase projects, which is the structural foundation for the rest of the roadmap.

`#423` as originally scoped covered only the Gradle flavor split (Android). However, the `com.google.gms.google-services` plugin validates that the `package_name` field in `google-services.json` matches the actual `applicationId`. Adding `applicationIdSuffix = ".staging"` / `".dev"` without also providing per-flavor `google-services.json` causes the build to fail at the plugin's validation step — not at runtime. The Acceptance criterion "produces an APK with package `.staging`" therefore cannot be met without the Firebase config injection that originally lived in #425.

Bundling the Android subset of #425 (Firebase project creation + Android per-flavor config + Android CI secret split + bootstrap scripts) into this PR resolves the gap. It keeps the staging deploy working continuously instead of breaking it between #423 and #425. iOS-side work (xcconfig, plist wiring) remains separate because it depends on #424, which is independent of Android.

## Scope reshape vs. original #418 layout

The umbrella roadmap decomposes Phase 1 into 5 task-cluster issues (#423-#427). This spec absorbs the Android subset of #425 into #423 and leaves #425 with only iOS-side work.

| Original issue | Original scope | New scope after this spec |
|---|---|---|
| #423 | Android flavor split only | Android flavor split + Android Firebase per-flavor config + Android CI secret split + bootstrap scripts (Android + iOS pre-position) |
| #424 | iOS scheme + xcconfig + `GIDClientID` parameterization | unchanged |
| #425 | Firebase 3-project setup + Android + iOS config injection + APNs upload | iOS Xcode plist wiring (Build Phase script) + APNs Auth Key upload + iOS CI secret injection |
| #426 | per-flavor app icons + labels | unchanged |
| #427 | per-env OAuth + Supabase auth + `FIREBASE_SERVICE_ACCOUNT` | unchanged |

After implementation merges, both #423 and the original Android portion of #425's checklist are satisfied. The issue text for #425 will be updated to reflect the iOS-only scope.

## Architectural decisions

### Flavor names: `dev` / `staging` / `production`

The lowest-environment flavor is named `dev`, not `debug`, to avoid the Android Gradle Plugin source-set collision between a flavor named `debug` and the built-in `debug` `buildType`. Both register a source set at `app/src/debug/`, so any per-flavor file in that directory (e.g., `AndroidManifest.xml` for #426's app label) would silently bleed into the `*Debug` `buildType` variants of every flavor.

For `google-services.json` specifically the collision is harmless because the plugin's resolution order prefers per-flavor (`#3`) over per-buildType (`#4`). But every subsequent per-flavor file would require a `src/debugDebug/` + `src/debugRelease/` variant-specific workaround or manifest placeholder. `dev` is the Flutter / mobile community convention and removes the entire class of footgun.

`staging` and `production` use their full names. `staging` has no collision concerns. `production` is the "unmarked default" — no bundle suffix, no env file suffix, no special source set — so it appears only inside code, CI workflows, and documentation, where the long form aids readability.

This naming is set up by precursor [#445](https://github.com/cloveclovedev/peppercheck/issues/445), which renames the existing in-code `AppEnvironment.debug` / `AppConfig.debug` / `main_debug.dart` / `.env.debug` to `dev` form, plus existing-resource rename targets (R2 bucket, Stripe sandbox, GitHub Secrets) where feasible. The implementation of this spec assumes #445 has merged.

### `google-services.json` placement

Per-flavor `google-services.json` files live at `peppercheck_flutter/android/app/src/<flavor>/google-services.json` for each of `dev`, `staging`, `production`. This is the Google-documented [recommended location](https://developers.google.com/android/guides/google-services-plugin#adding_the_json_file): the plugin resolves config files in the order

1. `src/<flavor><BuildType>/google-services.json`
2. `src/<buildType><Flavor>/google-services.json`
3. **`src/<flavor>/google-services.json`** ← used here
4. `src/<buildType>/google-services.json`
5. `src/google-services.json`

Per-flavor (`#3`) is preferred over per-buildType (`#4`), so a build variant like `stagingDebug` deterministically picks `src/staging/google-services.json` and ignores any other source-set file.

All three files are gitignored. Production's file is moved from its current location (`peppercheck_flutter/android/app/google-services.json`) into `src/production/google-services.json`; the old location is deleted to eliminate the plugin's fallback path (option `#5`) so a missing per-flavor file fails loudly rather than silently using stale config.

### Three Firebase projects, one project per environment

Firebase projects after this spec:

- `peppercheck` (existing) — production. One Android app (`dev.cloveclove.peppercheck`).
- `peppercheck-staging` (new) — staging. One Android app (`dev.cloveclove.peppercheck.staging`).
- `peppercheck-dev` (new) — dev. One Android app (`dev.cloveclove.peppercheck.dev`).

Each project also receives one iOS app entry registered by the bootstrap script (with its `GoogleService-Info-*.plist` pre-positioned in the repo), but the iOS plist is not read by Xcode until #424 / #425 wire it up.

PepperCheck's Firebase service usage (FCM, Crashlytics, Performance Monitoring, Analytics — the last three are planned for Phase 3a) is entirely Spark-plan-compatible. The bootstrap script does not prompt for Blaze. Blaze is needed only if Cloud Functions or Cloud Storage are introduced later, neither of which is on the roadmap (Edge Functions on Supabase and Cloudflare R2 cover those roles).

### Bootstrap scripts run on operator workstation, not CI

Two scripts at `scripts/setup/`:

- `bootstrap-firebase-projects.sh` — creates `peppercheck-dev` and `peppercheck-staging` via `firebase projects:create` if they do not exist. Idempotent.
- `register-firebase-apps.sh <env>` — registers one Android app and one iOS app in the target Firebase project (skipping if already present), then downloads `google-services.json` and `GoogleService-Info-<CapEnv>.plist` via `firebase apps:sdkconfig` into their per-flavor repo paths. Idempotent.

Both scripts:

- Assume the operator has run `firebase login` and has access to the parent organization.
- Write only into gitignored repo paths (no risk of committing secrets).
- Are safe to re-run after partial failure or for re-onboarding a fresh workstation.

The scripts run on the operator's machine, not in CI. CI continues to receive Firebase configs via GitHub Secrets (base64-encoded values written into the same per-flavor paths during the build job). The scripts exist for reproducibility and onboarding documentation, not for CI execution.

### iOS plist pre-positioning

`register-firebase-apps.sh <env>` downloads both Android and iOS configs in one invocation. The iOS `GoogleService-Info-<CapEnv>.plist` is placed at `peppercheck_flutter/ios/Runner/Firebase/GoogleService-Info-<CapEnv>.plist`. Xcode does not reference this path until #424 introduces per-scheme xcconfig and #425 introduces the Build Phase script that copies the right plist into the app bundle.

Pre-positioning ensures the operator runs `register-firebase-apps.sh` once per environment for this entire Phase 1 sequence rather than re-running it during each subsequent PR.

### `applicationIdSuffix` strategy

Industry standard:

| Flavor | `applicationId` | applied via |
|---|---|---|
| production | `dev.cloveclove.peppercheck` | `defaultConfig.applicationId` (no suffix) |
| staging | `dev.cloveclove.peppercheck.staging` | `applicationIdSuffix = ".staging"` |
| dev | `dev.cloveclove.peppercheck.dev` | `applicationIdSuffix = ".dev"` |

Suffix-at-end semantics match Google Play / App Store Connect's sort behavior, the umbrella roadmap's bundle-ID table, and the iOS xcconfig equivalents that #424 will produce.

### `versionCode` / `versionName` remain flavor-agnostic

The existing `defaultConfig.versionCode` / `versionName` apply to all three flavors. Environment-suffixed version structuring (e.g., `1.0.0-staging.123`) is explicitly deferred to [#438](https://github.com/cloveclovedev/peppercheck/issues/438).

### `buildTypes` unchanged

Default `debug` / `release` / `profile` buildTypes remain as-is. The existing release signing config (gated on `key.properties` presence) is shared across all three flavors.

### GitHub Secret naming follows `<ENV>_*` prefix

Existing `deploy-beta.yml` / `deploy-production.yml` use `PROD_*` and `BETA_*` prefixes consistently for env-scoped secrets (`PROD_SUPABASE_*`, `BETA_STRIPE_*`, `PROD_FIREBASE_SERVICE_ACCOUNT_JSON`, etc.). The legacy `GOOGLE_SERVICES_JSON` and `FIREBASE_APP_ID` secrets without prefix are exceptions left over from earlier work. This PR's implementation renames the legacy `GOOGLE_SERVICES_JSON` to `PROD_GOOGLE_SERVICES_JSON` alongside introducing `BETA_GOOGLE_SERVICES_JSON`, cleaning up the inconsistency in the same change. Dev is local-only in this PR — no `DEV_GOOGLE_SERVICES_JSON` is created (a future dev-channel CI build, if introduced, would add it).

### `flutter run` / `flutter build` require `--flavor`

With `productFlavors` declared, the Flutter tooling requires `--flavor <env>` on every invocation. Local development workflow becomes:

```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter build apk --release --flavor staging -t lib/main_staging.dart
flutter build appbundle --release --flavor production -t lib/main_production.dart
```

This is documented in `developer-docs/modules/ROOT/pages/flutter/initial-local-setup.adoc` as part of this PR.

## Components

### 1. `peppercheck_flutter/android/app/build.gradle.kts`

```kotlin
android {
    namespace = "dev.cloveclove.peppercheck"
    // ...existing config...

    defaultConfig {
        applicationId = "dev.cloveclove.peppercheck"
        // versionCode / versionName remain flavor-agnostic
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
        }
        create("production") {
            dimension = "environment"
            // no suffix — production is the unmarked default
        }
    }
}
```

The existing `signingConfigs` and `buildTypes` blocks are unchanged.

### 2. Per-flavor source-set directories

Created under `peppercheck_flutter/android/app/src/`:

- `dev/.gitkeep` (committed) + `dev/google-services.json` (gitignored)
- `staging/.gitkeep` (committed) + `staging/google-services.json` (gitignored)
- `production/.gitkeep` (committed) + `production/google-services.json` (gitignored)

`.gitkeep` files ensure the directories exist in fresh clones. The `google-services.json` files are produced locally by `register-firebase-apps.sh` and in CI by per-flavor GitHub Secrets.

### 3. iOS pre-positioned plist directory

Created under `peppercheck_flutter/ios/Runner/Firebase/`:

- `.gitkeep` (committed)
- `GoogleService-Info-Dev.plist` (gitignored, produced by `register-firebase-apps.sh dev`)
- `GoogleService-Info-Staging.plist` (gitignored, produced by `register-firebase-apps.sh staging`)
- `GoogleService-Info-Production.plist` (gitignored, produced by `register-firebase-apps.sh production`)

Xcode does not reference these paths until #424 / #425.

### 4. `.gitignore` updates

Inside `peppercheck_flutter/.gitignore`, replace:

```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

with:

```
android/app/src/*/google-services.json
ios/Runner/GoogleService-Info.plist
ios/Runner/Firebase/GoogleService-Info-*.plist
```

The legacy `ios/Runner/GoogleService-Info.plist` pattern stays until #424 / #425 fully migrate iOS off the legacy path.

### 5. `scripts/setup/bootstrap-firebase-projects.sh`

No arguments. Idempotent.

Behavior:

- Verify `firebase` CLI is installed and logged in (`firebase login:list` fails fast if not).
- For each of `peppercheck-dev`, `peppercheck-staging`:
  - Query `firebase projects:list --json | jq` to check existence.
  - If missing, run `firebase projects:create <id> --display-name "PepperCheck <CapEnv>"`.
- Print a one-line summary per project (`[create]` or `[skip]`).
- Exit 0 on success.

Does not prompt for Blaze upgrade.

### 6. `scripts/setup/register-firebase-apps.sh <env>`

Argument: `env` ∈ {`dev`, `staging`, `production`}. Idempotent.

Behavior:

- Resolve from `env`:
  - `project_id` = `peppercheck` if production, else `peppercheck-<env>`.
  - `bundle_id` = `dev.cloveclove.peppercheck` + (`.<env>` for non-production, empty for production).
  - `cap_env` = `Dev` / `Staging` / `Production`.
- For each platform (ANDROID, IOS):
  - Query `firebase apps:list --project <project_id>` for an existing app matching the bundle ID.
  - If absent, run `firebase apps:create <PLATFORM> "PepperCheck <CapEnv> (<Platform>)" --bundle-id <bundle_id> --project <project_id>` (or `--package-name` for Android).
  - Run `firebase apps:sdkconfig <PLATFORM> <app_id> --project <project_id> --out <target_path>`.
- Target paths (computed relative to `git rev-parse --show-toplevel`):
  - Android: `peppercheck_flutter/android/app/src/<env>/google-services.json`
  - iOS: `peppercheck_flutter/ios/Runner/Firebase/GoogleService-Info-<CapEnv>.plist`
- Exit non-zero on unknown `env` argument or any `firebase` CLI failure.

For `production`, the project `peppercheck` and both its Android and iOS app entries pre-exist (the production iOS app was registered when `ios/Runner/GoogleService-Info.plist` was first added to the repo). The script's `firebase apps:list` query returns the existing entries, so `apps:create` is skipped on both platforms and only `apps:sdkconfig` runs. This makes `register-firebase-apps.sh production` safe for re-onboarding a fresh workstation without disturbing existing Firebase resources.

Both scripts use `set -euo pipefail` and pre-flight check for `firebase` and `jq` on `PATH`.

### 7. `.github/workflows/deploy-beta.yml`

The current Android build job uses a single `GOOGLE_SERVICES_JSON` secret. After this PR:

- New GitHub Secret `BETA_GOOGLE_SERVICES_JSON` is created by the operator (base64-encoded `google-services.json` from the `peppercheck-staging` Firebase project).
- The workflow's Android build job:
  - Writes the secret to `peppercheck_flutter/android/app/src/staging/google-services.json` before the `flutter build apk` step.
  - Invokes `flutter build apk --release -t lib/main_staging.dart --flavor staging` (added `--flavor staging`).
- The Firebase App Distribution upload step's `appId` reference is updated to point at the `peppercheck-staging` Firebase project's new staging Android app entry. The FAD testers group must be re-created (or re-pointed) in the new project as part of operator pre-merge work.

### 8. `.github/workflows/deploy-production.yml`

- The existing GitHub Secret `GOOGLE_SERVICES_JSON` is renamed to `PROD_GOOGLE_SERVICES_JSON` (same value).
- The workflow's Android build job:
  - Writes the secret to `peppercheck_flutter/android/app/src/production/google-services.json` (replacing the previous `android/app/google-services.json` target).
  - Invokes `flutter build appbundle --release -t lib/main_production.dart --flavor production` (added `--flavor production`).

The production AAB's package name remains `dev.cloveclove.peppercheck`, so Play Store / FAD upload steps need no app-entry changes.

### 9. `developer-docs/modules/ROOT/pages/flutter/initial-local-setup.adoc`

Add a "Per-flavor builds" section explaining:

- `--flavor <env>` is required on every `flutter run` / `flutter build` invocation after this PR.
- First-time local setup runs `./scripts/setup/register-firebase-apps.sh dev` to fetch `dev`'s `google-services.json`. Operators with access to staging or production secrets may run the script for those envs too; otherwise, those builds are CI-only.
- The exact local-dev command becomes `flutter run --flavor dev -t lib/main_dev.dart`.

Pointer to the umbrella roadmap and to bootstrap-script usage.

## Data flow

```
Operator workstation
  ├─ firebase login                          (one-time, manual)
  ├─ bootstrap-firebase-projects.sh          → creates peppercheck-{dev,staging} via Firebase API
  └─ register-firebase-apps.sh {dev|staging|production}
       ├─ firebase apps:create ANDROID|IOS    (skip if exists)
       └─ firebase apps:sdkconfig             → writes gitignored config files into repo

GitHub Secrets (operator-managed, base64-encoded values of the google-services.json files)
  ├─ PROD_GOOGLE_SERVICES_JSON   (renamed from GOOGLE_SERVICES_JSON)
  └─ BETA_GOOGLE_SERVICES_JSON      (new)

CI deploy-beta.yml (on push to beta/v*)
  └─ Write BETA_GOOGLE_SERVICES_JSON → src/staging/google-services.json
     └─ flutter build apk --flavor staging --release → APK (dev.cloveclove.peppercheck.staging)
        └─ Firebase App Distribution upload to peppercheck-staging project's staging Android app

CI deploy-production.yml (on push to v* tag)
  └─ Write PROD_GOOGLE_SERVICES_JSON → src/production/google-services.json
     └─ flutter build appbundle --flavor production --release → AAB (dev.cloveclove.peppercheck)
        └─ Existing Play Store + FAD upload steps (no app-entry change)
```

## Acceptance

- [ ] `flutter build apk --flavor production -t lib/main_production.dart` produces an APK with package `dev.cloveclove.peppercheck`.
- [ ] `flutter build apk --flavor staging -t lib/main_staging.dart` produces an APK with package `dev.cloveclove.peppercheck.staging`.
- [ ] `flutter build apk --flavor dev -t lib/main_dev.dart` produces an APK with package `dev.cloveclove.peppercheck.dev`.
- [ ] All three APKs install side-by-side on a single Android device.
- [ ] Each running build registers FCM tokens into its own Firebase project (verified via Firebase Console → Cloud Messaging → Reports per project).
- [ ] Existing `deploy-production.yml` produces an AAB with package `dev.cloveclove.peppercheck` and uploads it to the existing Play Store / FAD entries without entry changes.
- [ ] `deploy-beta.yml` produces an APK with package `.staging` and uploads it to the new `peppercheck-staging` Firebase project's FAD entry.
- [ ] `developer-docs` per-flavor build instructions are reproducible by a fresh contributor.

## Operator runbook (pre-implementation-PR-merge)

Performed once by the operator before merging the implementation PR.

- [ ] `firebase login` (skip if already logged in).
- [ ] `./scripts/setup/bootstrap-firebase-projects.sh` → creates `peppercheck-dev` and `peppercheck-staging`.
- [ ] `./scripts/setup/register-firebase-apps.sh dev` → downloads dev configs.
- [ ] `./scripts/setup/register-firebase-apps.sh staging` → downloads staging configs.
- [ ] `./scripts/setup/register-firebase-apps.sh production` → re-downloads production configs (validates idempotence).
- [ ] Create GitHub Secret `BETA_GOOGLE_SERVICES_JSON` (base64-encoded value of `peppercheck-staging`'s `google-services.json`).
- [ ] Rename GitHub Secret `GOOGLE_SERVICES_JSON` → `PROD_GOOGLE_SERVICES_JSON` (same value).
- [ ] In the `peppercheck-staging` Firebase Console: enable Firebase App Distribution for the new staging Android app, re-create the testers group, and capture the new `appId` to update in `deploy-beta.yml`.

Operator can run the bootstrap script for production at any time; it is idempotent and only re-downloads config.

## Out of scope

This PR's implementation does **not** include:

- iOS scheme / xcconfig changes (#424).
- iOS `Build Phase` script that copies the right `GoogleService-Info-*.plist` per scheme (#425).
- iOS CI secret split (`GOOGLE_SERVICE_INFO_PLIST_*`) (#425).
- APNs Auth Key (`.p8`) upload to all three Firebase projects (#425).
- Per-flavor app icons (#426).
- Per-flavor Android `android:label` / iOS display name (#426).
- Per-environment Google Sign-In OAuth clients (#427).
- Supabase auth provider configuration per project (#427).
- `FIREBASE_SERVICE_ACCOUNT` reconciliation per Supabase project (#427).
- `versionNameSuffix` / environment-suffixed version structuring (#438).
- Apple Connect / Play Console app registration for staging and debug bundle IDs (Phase 2).

## Implementation notes

- The flavor naming is `dev` / `staging` / `production`. Precursor #445 will have already renamed the existing `debug` references in code, env files, R2 bucket (where feasible), Stripe sandbox name, and GitHub Secrets prefixes. Verify #445 is merged into `main` before starting implementation of this spec.
- The `google-services` plugin's path-resolution order is `src/<flavor><BuildType>/` → `src/<buildType><Flavor>/` → `src/<flavor>/` → `src/<buildType>/` → `src/<root>/`. The per-flavor-only path is preferred over per-buildType, so `src/dev/google-services.json` is unambiguously the dev-flavor's config regardless of buildType.
- Delete the existing `peppercheck_flutter/android/app/google-services.json` after moving its contents to `src/production/google-services.json`. Leaving the file in place creates a silent fallback that would mask a missing per-flavor file in future regressions.
- The bootstrap scripts should not prompt for Blaze. Spark is sufficient for PepperCheck's Firebase usage (FCM, Crashlytics, Performance, Analytics). Blaze is required only for Cloud Functions or Cloud Storage, neither of which is on the roadmap.
- iOS `GoogleService-Info-*.plist` files are pre-positioned by the bootstrap script but not referenced by Xcode in this PR. They become live in #424 / #425.
- After this PR, `flutter run` and `flutter build` require `--flavor <env>`. Update local launch configurations (if any) and CI invocations accordingly.

## Dependencies

- **Requires merged:** #445 (debug → dev rename precursor).
- **Blocks:** #426 (per-flavor app icons + labels) — depends on the source-set directories.
- **Coordinates with:** #424 (iOS schemes) and reshaped #425 (iOS Firebase config + APNs) — these can proceed in parallel to or after this spec's implementation. The iOS plists pre-positioned here are inputs to #424 / #425.

## References

### Existing design docs

- [Multi-environment setup roadmap](2026-05-11-multi-environment-setup-roadmap-design.md) — umbrella, defines Phase 1 / 2 / 3a scope.
- [Stripe debug sandbox](2026-05-31-stripe-debug-sandbox-design.md) — Phase 0 sibling.

### GitHub issues

- Parent: [#418](https://github.com/cloveclovedev/peppercheck/issues/418).
- Implements: [#423](https://github.com/cloveclovedev/peppercheck/issues/423) (expanded scope) and the Android subset of [#425](https://github.com/cloveclovedev/peppercheck/issues/425).
- Precursor: [#445](https://github.com/cloveclovedev/peppercheck/issues/445).

### External documentation

- [Google services Gradle plugin — Adding the JSON file](https://developers.google.com/android/guides/google-services-plugin#adding_the_json_file)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Firebase pricing — Spark vs Blaze](https://firebase.google.com/pricing)

### Project conventions

- `.claude/rules/supabase-workflow.md`
- `.claude/rules/release-branch-tag-workflow.md`
- `.claude/rules/flutter.md`
- (new in #421) `.claude/rules/multi-environment-setup.md`

## Revision log

| Date | Change |
|---|---|
| 2026-06-05 | Initial draft. Captures the brainstormed decision to bundle Android subset of #425 into #423 and to gate this spec's implementation on #445. |
