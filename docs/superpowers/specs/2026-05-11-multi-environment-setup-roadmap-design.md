# Multi-Environment Setup Roadmap

**Date:** 2026-05-11
**Status:** Draft
**Type:** Umbrella roadmap (decomposes into a flat list of task-cluster issues; no Phase-level intermediate issue)

## Goal

Make PepperCheck's three environments — **production**, **staging**, and **debug** — independently usable for end-to-end validation. Each environment must:

1. Operate without side effects leaking to other environments.
2. Be installable side-by-side on the same device with a uniform operator workflow.
3. Be immediately distinguishable by an operator inspecting a running app.

## Why now

Through the v1.0.0 production release, integrations with side effects (subscription IAP, push notifications, Stripe Connect payouts, Google Play RTDN, Apple ASSN) were validated **in production**. This pattern:

- Mixes test-origin notifications and data with real users.
- Defers regression detection until after a tag is cut and deployed.
- Makes incident rollback and reproduction hard.

It does not scale through the upcoming subscription-related changes (further iteration on the Freemium points system, iOS IAP, payout flows, etc.).

## Current state

### Already isolated

- **R2 buckets**: `peppercheck` (prod), `peppercheck-staging`, `peppercheck-debug`. Selected by Edge Functions via `R2_BUCKET_NAME`.
- **Webapp deployment**: Cloudflare Workers with `wrangler.jsonc` `[env.staging]` (`staging.peppercheck.dev`) and `[env.production]` (`peppercheck.dev`).
- **Build-time env injection (Flutter / webapp)**: CI workflows (`deploy-beta.yml`, `deploy-production.yml`) generate `assets/env/.env.{staging,production}` and webapp `.env.local` from env-scoped GitHub Secrets (`BETA_*`, `PROD_*`).
- **Supabase projects**: Distinct `BETA_SUPABASE_*` and `PROD_SUPABASE_*` projects.
- **Stripe**: Live mode for production payouts; one sandbox shared between staging and debug.

### Not isolated or shared (this roadmap's scope)

- **Bundle ID / package name**: A single `dev.cloveclove.peppercheck` is reused across all flavors.
- **Firebase project**: One Firebase project (`peppercheck`) is shared across debug, staging, and production.
- **Apple Connect / Play Console apps**: One per platform, shared across all flavors.
- **Google Play RTDN topic**: One topic; staging internal-testing purchases reach the production Supabase webhook.
- **Stripe sandbox**: Staging and debug share one sandbox, so a local-debug event reaches the staging Supabase function.
- **Edge Function runtime secrets**: Set manually per project via `supabase secrets set`; no CI automation or runbook.
- **Stripe webhook routing**: live → PROD Supabase is wired; sandbox → BETA Supabase exists, but the staging/debug share creates noise.
- **In-app environment indicator**: No on-screen banner identifies which environment a running build is connected to.
- **Mobile observability**: Firebase Crashlytics, Performance Monitoring, and Analytics are not enabled.

### State matrix

Legend: ✅ isolated per environment, ⚠️ shared or not isolated, 🆕 not introduced.

| Subsystem | production | staging | debug | Notes |
|---|---|---|---|---|
| Supabase project | ✅ PROD | ✅ BETA | ✅ local | Per-env secrets in CI |
| Supabase migration deploy | ✅ tag → push | ✅ beta branch → push | ✅ `supabase db reset` | |
| Edge Function deploy | ✅ tag | ✅ beta branch | ✅ `functions serve` | 11 functions |
| Edge Function runtime secret | ⚠️ manual | ⚠️ manual | ⚠️ manual `supabase/.env` | |
| R2 bucket | ✅ `peppercheck` | ✅ `peppercheck-staging` | ✅ `peppercheck-debug` | |
| Webapp deploy | ✅ `peppercheck.dev` | ✅ `staging.peppercheck.dev` | ✅ `npm run dev` | |
| Build-time env injection | ✅ `PROD_*` | ✅ `BETA_*` | ✅ local file | |
| Bundle ID / package | ⚠️ shared | ⚠️ shared | ⚠️ shared | |
| Firebase project | ⚠️ shared | ⚠️ shared | ⚠️ shared | One project across all |
| `google-services.json` / `GoogleService-Info.plist` | ⚠️ single secret | ⚠️ same | ⚠️ per-developer copy | |
| APNs Auth Key | ⚠️ one project | ⚠️ same | ⚠️ same | |
| Google Sign-In OAuth client | ⚠️ shared Web + Android client | ⚠️ shared (no staging app) | ⚠️ separate Android client (debug fingerprint) | Web client configured in Supabase Dashboard |
| iOS `GIDClientID` | ⚠️ hard-coded | ⚠️ same | ⚠️ same | Should move to xcconfig |
| Android signing keystore | ✅ release upload key + Play App Signing | ✅ same (internal testing) | ✅ debug.keystore | Play App Signing fingerprint is the one registered with Firebase / OAuth |
| Apple Connect app | ⚠️ one | ⚠️ same | ⚠️ same | |
| Play Console app | ⚠️ one | ⚠️ same | ⚠️ same | |
| IAP product registration | ⚠️ single app | ⚠️ same | ⚠️ same | |
| Apple ASSN V2 webhook URL | ✅ Production URL → PROD | ✅ Sandbox URL → BETA | n/a (sandbox URL shared) | Single-app dual-URL split |
| Google Play RTDN Pub/Sub | ⚠️ one topic → PROD | ⚠️ internal-testing purchases → same topic | n/a | |
| Stripe live/sandbox | ✅ live → PROD | ✅ sandbox A → BETA | ⚠️ shared sandbox A with staging | Debug sandbox to be created |
| Stripe webhook endpoint | ✅ live URL → PROD | ✅ sandbox URL → BETA | n/a (stripe-cli forwarding) | |
| Mobile crash / performance / analytics | 🆕 none | 🆕 none | 🆕 none | Firebase suite not enabled |
| In-app environment badge | ⚠️ none | ⚠️ none | ⚠️ none | |

## Non-goals

- Re-design existing CI build-time env injection — reuse it.
- Migrate Stripe billing flows to live mode — subscription is IAP-only by policy; Stripe live is for payout only and already works.
- Split deep-link domains (`app.peppercheck.dev` vs `staging.app.peppercheck.dev`) — no AASA / assetlinks file exists today; revisit when universal links are introduced.
- Implement migrations or per-Phase implementation work — each Phase decomposes into separate issues and PRs.

## Target state

### Architectural decisions

#### Bundle ID per flavor

| Flavor | iOS bundle ID / Android package |
|---|---|
| production | `dev.cloveclove.peppercheck` (existing) |
| staging | `dev.cloveclove.peppercheck.staging` |
| debug | `dev.cloveclove.peppercheck.debug` |

- Android: `productFlavors` with `applicationIdSuffix = ".staging"` / `".debug"`.
- iOS: per-scheme xcconfig overriding `PRODUCT_BUNDLE_IDENTIFIER`; three schemes (`Runner-Debug`, `Runner-Staging`, `Runner-Production`).
- Suffix-at-end form is the industry standard (matches `applicationIdSuffix` semantics, sorts adjacently in Apple/Google consoles, reads as `org → app → variant`).

#### Three Firebase projects

- `peppercheck` (existing, reused for production)
- `peppercheck-staging` (new)
- `peppercheck-debug` (new, operator-managed)
- Each project hosts one iOS app and one Android app for its flavor (6 apps total).
- A single APNs Auth Key (`.p8`) is generated once on the Apple Developer Team and registered in all three projects.
- `FIREBASE_SERVICE_ACCOUNT` is set per Supabase project (PROD project gets the production project's service account, BETA project gets the staging project's). Edge Function code does not branch on environment — it simply reads its single env var.

#### Google Sign-In OAuth clients

- **Web OAuth client**: one per Supabase project (3 total), used as `serverClientId` in the native Google Sign-In flow and registered as the auth provider in Supabase Dashboard.
- **Android OAuth client**: one per (env × signing fingerprint). Production and staging use their respective Play App Signing fingerprints; debug uses `debug.keystore` fingerprints (one per developer).
- **iOS OAuth client**: per env (3 total). `Info.plist` `GIDClientID` is parameterized through xcconfig.

#### Apple Connect / Play Console apps

- Three Apple Connect apps and three Play Console apps (production / staging / debug). IAP products are duplicated across the three.
- Distribution:
  - production app: App Store + TestFlight + Play Store
  - staging app: TestFlight internal testing + Play internal testing track
  - debug app: not distributed via store, IAP product registration only (so local builds can fetch products)

#### Webhook routing

**Apple ASSN V2:**

| Apple Connect app | Production URL | Sandbox URL |
|---|---|---|
| production | → PROD Supabase | (empty) |
| staging | → BETA Supabase | (empty) |
| debug | (empty) | (empty) |

Rationale for empty Sandbox URLs:

- TestFlight purchases (free) run in the production environment and hit Production URL.
- Sandbox environment fires only when Xcode debug builds are run with a Sandbox tester Apple ID. Those builds use the `.debug` bundle ID; their notifications would route to the debug app's Sandbox URL. Local end-to-end ASSN testing is intentionally out of scope — server-side ASSN flows are validated through TestFlight on the staging app (which makes all purchases free, so no real money is required).

**Google Play RTDN:**

| Play app | Pub/Sub topic | Destination |
|---|---|---|
| production | existing topic | PROD Supabase `handle-google-play-rtdn` |
| staging | new `peppercheck-rtdn-staging` | BETA Supabase `handle-google-play-rtdn` |
| debug | none | n/a |

**Stripe webhooks:**

| Environment | Stripe context | Webhook URL |
|---|---|---|
| production | live mode | PROD Supabase `handle-stripe-webhook` |
| staging | sandbox A | BETA Supabase `handle-stripe-webhook` |
| debug | sandbox B (new) | none (use `stripe listen --forward-to` for local) |

#### Edge Function runtime secrets

- CI deploy workflows (`deploy-beta.yml`, `deploy-production.yml`) run `supabase secrets set --project-ref <env>` on every deploy. Idempotent. GitHub Secrets is the source of truth.
- One-off updates via Supabase Dashboard remain acceptable; the next CI deploy reconciles the state.
- Required secret list is documented in `developer-docs/`.

#### Mobile observability

- Firebase Crashlytics, Performance Monitoring, and Analytics enabled in all three Firebase projects.
- Crashlytics dSYM (iOS) and ProGuard mapping (Android) uploaded by CI.

#### In-app environment badge

- A banner widget reads `AppConfig.environment` and, for non-production builds, displays a fixed colored bar at the top of the app:
  - staging: yellow, label "STAGING"
  - debug: green, label "DEBUG"
- App icon variants reinforce the same distinction on the home screen.

### Topology

```
production
  App        : dev.cloveclove.peppercheck (App Store / Play Store)
  Firebase   : peppercheck
  Supabase   : PROD
  Webapp     : peppercheck.dev
  R2         : peppercheck
  Stripe     : live → PROD Supabase webhook
  ASSN       : production app → Production URL → PROD Supabase
  RTDN       : production Play app → existing topic → PROD Supabase
  OAuth      : prod Web client, prod Android client (Play App Signing fingerprint)

staging
  App        : dev.cloveclove.peppercheck.staging (TestFlight / internal track)
  Firebase   : peppercheck-staging
  Supabase   : BETA
  Webapp     : staging.peppercheck.dev
  R2         : peppercheck-staging
  Stripe     : sandbox A → BETA Supabase webhook
  ASSN       : staging app → Production URL → BETA Supabase
  RTDN       : staging Play app → peppercheck-rtdn-staging → BETA Supabase
  OAuth      : staging Web client (Supabase BETA), staging Android client

debug
  App        : dev.cloveclove.peppercheck.debug (local only)
  Firebase   : peppercheck-debug
  Supabase   : local (`supabase start`)
  Webapp     : localhost:3000 (`npm run dev`)
  R2         : peppercheck-debug
  Stripe     : sandbox B → stripe-cli forward → localhost
  ASSN       : no URLs (server-side ASSN validated via staging TestFlight)
  RTDN       : none
  OAuth      : dev Web client (local Supabase), debug Android client (debug.keystore)
```

## Phases

Each task is labeled by its automation potential:

- 🤖 Scriptable — fully runnable via CLI / API (`gcloud`, `firebase`, `supabase`, App Store Connect API, Play Developer API, etc.)
- 🔧 Semi-automated — scripts cover most of the work, some console / IDE interaction required
- ✋ GUI only — requires manual console interaction (no API available, or one-time setup)

Scriptable steps land under `scripts/setup/`. Scripts read credentials from environment variables or `~/.config/peppercheck-secrets/`. Credentials are never written to the repository.

### Phase 0: Pre-work

**Goal:** Strengthen the existing isolation foundation. No bundle ID changes yet.

| # | Task | Label |
|---|---|---|
| 0.1 | Read `AppConfig.environment` and render a non-production banner widget at the top of the app (yellow "STAGING" / green "DEBUG"). | 🤖 PR |
| 0.2 | Add `supabase secrets set` step to `deploy-beta.yml` and `deploy-production.yml` so all Edge Function runtime secrets are reconciled on every deploy. | 🤖 PR |
| 0.3 | Add `developer-docs/modules/ROOT/pages/operations/secret-management.adoc` listing required secrets per environment and documenting the "CI reconciles on every deploy; one-off updates via dashboard are fine" policy. | 🤖 PR |
| 0.4 | Create a dedicated Stripe sandbox for debug and issue `DEBUG_STRIPE_PUBLISHABLE_KEY` / `DEBUG_STRIPE_SECRET_KEY`. | ✋ Stripe Dashboard |
| 0.5 | Add `developer-docs/modules/ROOT/pages/operations/stripe-cli-setup.adoc` documenting `stripe login` against the debug sandbox and `stripe listen --forward-to http://localhost:54321/functions/v1/handle-stripe-webhook`. | 🤖 PR |
| 0.6 | Add `.claude/rules/multi-environment-setup.md` capturing the per-environment operational assumptions for AI tooling. | 🤖 PR |

**Dependencies:** none.

**Verification:** After staging deploy, the staging build shows the "STAGING" banner; `supabase secrets list --project-ref <BETA>` reflects all expected secrets; the debug sandbox boots and `stripe listen` forwards an event to local Supabase.

**Issue layout:** 4 task-cluster issues filed directly under the umbrella — `env banner`, `CI secret automation`, `operations runbook`, `debug Stripe sandbox`. Phase 0 itself is not a GitHub issue. Each cluster is sized to roughly one PR (the debug Stripe sandbox issue tracks an operator-side manual task with no PR).

### Phase 1: Bundle ID + Firebase 3-project + Auth split

**Goal:** Per-flavor app identity, three independent Firebase projects, environment-isolated push and Google Sign-In.

| # | Task | Label |
|---|---|---|
| 1.1 | Android: declare `productFlavors` in `android/app/build.gradle.kts` (`debug` / `staging` / `production`) with `applicationIdSuffix`; add per-flavor source sets. | 🤖 PR |
| 1.2 | iOS: create three schemes (`Runner-Debug`, `Runner-Staging`, `Runner-Production`) with three xcconfig files overriding `PRODUCT_BUNDLE_IDENTIFIER`. | 🔧 Xcode + pbxproj diff |
| 1.3 | iOS: replace the hard-coded `GIDClientID` in `Info.plist` with an xcconfig variable. | 🤖 PR |
| 1.4 | `scripts/setup/bootstrap-firebase-projects.sh`: create `peppercheck-staging` and `peppercheck-debug` via `firebase projects:create`; confirm Blaze plan as needed. | 🤖 |
| 1.5 | `scripts/setup/register-firebase-apps.sh <env>`: create iOS + Android apps in the target project via `firebase apps:create` and download configs via `firebase apps:sdkconfig`. | 🤖 |
| 1.6 | Place per-flavor config files: `android/app/src/{debug,staging,production}/google-services.json` and `ios/Runner/Firebase/GoogleService-Info-{Debug,Staging,Production}.plist` (all gitignored, injected by CI). | 🤖 |
| 1.7 | CI workflow updates: split `GOOGLE_SERVICES_JSON` into `GOOGLE_SERVICES_JSON_{STAGING,PRODUCTION}` and write each to the matching source set path. | 🤖 PR |
| 1.8 | Upload the APNs Auth Key (one `.p8`) to all three Firebase projects with the same Team ID and Key ID. | ✋ Firebase Console |
| 1.9 | `scripts/setup/create-oauth-clients.sh <env>`: create the Web OAuth client and Android OAuth clients via Google Cloud REST API (with a setup service account); record client IDs. | 🔧 |
| 1.10 | Register each environment's Web OAuth client in the corresponding Supabase project's Google auth provider. | ✋ Supabase Dashboard (or 🔧 via Supabase Management API) |
| 1.11 | Set `FIREBASE_SERVICE_ACCOUNT` per Supabase project (each pointing to its matching Firebase project's service account). | 🤖 (Phase 0 mechanism) |
| 1.12 | Add per-flavor app icons (debug green, staging yellow, production normal). | 🤖 PR |
| 1.13 | Verification: build and run all three flavors on real devices, sign in, and confirm test push notifications arrive in each environment via its own Edge Function `send-notification`. | 🔧 |

**Dependencies:** Phase 0 complete.

**Verification:** `flutter run --flavor <env>` succeeds for all three flavors; Google Sign-In completes; each FCM token registers in its environment's Supabase and receives a notification triggered through that environment's Edge Function.

**Issue layout:** 5 task-cluster issues filed directly under the umbrella — `Android flavor split`, `iOS scheme split`, `Firebase project + apps + CI config injection`, `per-flavor app icons`, `per-env OAuth + Supabase auth config`. Each cluster is roughly one PR.

### Phase 2: Store registration + IAP staging + iOS publishing

**Goal:** Register staging and debug apps with Apple Connect and Play Console, route their store webhooks to BETA Supabase, and stand up iOS publishing automation alongside the existing Android pipeline.

| # | Task | Label |
|---|---|---|
| 2.1 | Register `.staging` and `.debug` bundle IDs on Apple Developer Portal via App Store Connect API `bundleIds` endpoint. | 🤖 (`register-apple-bundle-ids.sh`) |
| 2.2 | Create the Apple Connect staging app via App Store Connect API `apps`. | 🤖 |
| 2.3 | Create the Apple Connect debug app (IAP only, no store distribution). | 🤖 |
| 2.4 | Clone IAP products from the production app into the staging and debug apps. | 🤖 (`clone-iap-products.sh`) |
| 2.5 | Configure ASSN V2 URLs on the staging app: Production URL → BETA Supabase, Sandbox URL empty. | 🤖 |
| 2.6 | Create the TestFlight internal testing group on the staging app and invite testers. | 🔧 (API + Connect UI) |
| 2.7 | Create the Play Console staging app for `dev.cloveclove.peppercheck.staging`. | ✋ Play Console (no API) |
| 2.8 | Register IAP products in the Play Console staging app via Play Developer API `inappproducts`. | 🤖 |
| 2.9 | `scripts/setup/bootstrap-gcp-pubsub.sh staging`: create the `peppercheck-rtdn-staging` topic, push subscription, and endpoint binding to BETA Supabase `handle-google-play-rtdn`. | 🤖 |
| 2.10 | Configure the Play Console staging app's RTDN to publish to `peppercheck-rtdn-staging`. | ✋ Play Console |
| 2.11 | Set `GOOGLE_PUBSUB_*` in BETA Supabase for the new staging topic via the CI secret reconciliation. | 🤖 |
| 2.12 | Update `deploy-beta.yml` to upload the staging APK to the Play Console staging app's internal testing track (replacing or supplementing the existing Firebase App Distribution step). | 🤖 PR |
| 2.13 | Update `deploy-production.yml` to upload the production AAB to the Play Console production app via `r0adkll/upload-google-play` (TODO referenced in the file). | 🤖 PR |
| 2.14 | Add an iOS build job to `deploy-beta.yml` (macos-latest) that runs `xcodebuild archive` and uploads to TestFlight on the staging app. | 🤖 PR |
| 2.15 | Add an iOS build job to `deploy-production.yml` that uploads to TestFlight on the production app (App Store submission remains manual). | 🤖 PR |
| 2.16 | Register Apple Code Signing secrets in GitHub Secrets: `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY` (base64 `.p8`), distribution certificate, provisioning profiles. | 🔧 |
| 2.17 | Verification: install staging app via TestFlight and Play internal testing track; complete IAP subscribe / cancel / renew with operator Apple ID and Play license tester; confirm ASSN / RTDN reach BETA Supabase and the subscription DB updates accordingly. | 🔧 |

**Dependencies:** Phase 1 complete.

**Verification:** subscribe / cancel / renew lifecycle observable end-to-end in BETA Supabase for both platforms; production tag triggers a TestFlight build for iOS and a Play Store internal upload for Android.

**Issue layout:** 5 task-cluster issues filed directly under the umbrella — `Apple Connect staging+debug apps + IAP + ASSN`, `Play Console staging app + IAP`, `staging RTDN Pub/Sub`, `Play Store upload automation`, `iOS TestFlight upload automation`. Each cluster is roughly one PR.

### Phase 3a: Mobile observability (Firebase suite)

**Goal:** Enable Crashlytics, Performance Monitoring, and Analytics in each of the three Firebase projects.

| # | Task | Label |
|---|---|---|
| 3a.1 | Add `firebase_crashlytics`, `firebase_performance`, `firebase_analytics` to `pubspec.yaml`. | 🤖 PR |
| 3a.2 | Wire `FlutterError.onError` to `FirebaseCrashlytics.recordFlutterError` in `app_startup.dart`. | 🤖 PR |
| 3a.3 | iOS: add the Crashlytics dSYM upload script via `Podfile` `post_install`; add a dSYM upload step to `deploy-beta.yml` / `deploy-production.yml`. | 🤖 PR |
| 3a.4 | Android: enable the Firebase Crashlytics Gradle plugin and ProGuard mapping upload. | 🤖 PR |
| 3a.5 | Add `.claude/rules/analytics-events.md` defining the event naming convention. | 🤖 PR |
| 3a.6 | Verification: trigger an intentional crash in each flavor; confirm receipt in the matching Firebase project Crashlytics dashboard. Confirm auto-traced performance metrics appear. | 🔧 |

**Dependencies:** Phase 1 complete.

**Verification:** Three Firebase Console Crashlytics dashboards show independent crash streams; Analytics + Performance separated cleanly.

**Issue layout:** 2 task-cluster issues filed directly under the umbrella — `Firebase Crashlytics + Performance Monitoring`, `Firebase Analytics + event naming convention`. Each cluster is roughly one PR.

### Scriptable ratio

| Phase | 🤖 | 🔧 | ✋ | Scriptable % |
|---|---|---|---|---|
| Phase 0 | 5 | 0 | 1 | 83% |
| Phase 1 | 8 | 3 | 2 | 62% |
| Phase 2 | 12 | 3 | 2 | 71% |
| Phase 3a | 5 | 1 | 0 | 83% |

GUI-only steps that cannot be scripted:

- Create Stripe debug sandbox (Stripe Dashboard, Phase 0)
- Upload APNs Auth Key (Firebase Console, Phase 1)
- Create Play Console staging app and configure RTDN target topic (Play Console, Phase 2)
- Register Supabase Google auth provider (Supabase Dashboard; Management API may substitute, Phase 1)

## Out of scope

### Outright excluded

- **Stripe live mode migration for billing**: subscription is IAP-only by policy; Stripe live mode runs payout only and already works.
- **Deep-link domain split**: no AASA / assetlinks file exists today; revisit when universal links are introduced.
- **Cron job environment gating**: with Firebase, Stripe, and Play app separation in place, cross-environment side effects are contained. Re-evaluate only if a future change reintroduces shared side-effect surfaces (e.g., putting a Stripe live key in staging).
- **Production dry-run of `supabase db push`**: the existing beta dry-run plus the tag-based release gate provide sufficient pre-prod inspection. Adding prod dry-run yields marginal value under PepperCheck's single-train release flow.

### Future work

- **Sentry or equivalent server-side error tracking**: Edge Functions and Cloudflare Workers fall back on Supabase logs and Cloudflare Observability for now.
- **OSS contributor mock services + operator debug ergonomics**: a debug-only layer that bypasses real external services. Two motivations:
  - OSS contributor onboarding: run a debug build without provisioning Firebase, Stripe, R2, Apple Developer, or Play Console accounts.
  - Operator debug ergonomics: validate subscription / point grant / payout flows without going through a TestFlight review cycle.
  - Implementation ideas (separate spec): a debug-only "simulated purchase" button that calls the Edge Function to grant a subscription tier directly; a "simulated payout" button that updates the ledger without invoking Stripe Connect; a "simulated push trigger" that fires a local notification. Mock layer enabled only when `AppConfig.environment == debug`, dead-code-eliminated otherwise.
- **Developer-docs restructure**: tracked separately ([#400](https://github.com/cloveclovedev/peppercheck/issues/400)).
- **Apple App Store submission automation**: TestFlight upload is in Phase 2; full App Store submission (screenshots, release notes, phased rollout) is deferred to a separate spec.
- **Play Store submission automation beyond internal track**: Phase 2 covers internal-track upload; production-track promotion automation is deferred.
- **App version structuring**: introducing environment-suffixed version strings (e.g., `1.0.0-staging.123`) is deferred.

### Not designed here, tracked elsewhere

- Migration of remaining files from `docs/plans/` to `docs/superpowers/specs/` — separate PR.
- Renaming the Flutter `billing/` feature directory to `point/` — separate PR.

## Open questions / decisions deferred

### Decide before Phase 1 (blocking)

#### Web OAuth client architecture

- (a) One shared Web OAuth client referenced by all three Supabase projects.
- (b) Three Web OAuth clients, one per Supabase project, injected per flavor as `serverClientId`.

**Recommendation:** (b). Aligns with the "independent environments" principle; the marginal management cost is justified by the isolation gain.

#### iOS `CFBundleDisplayName` per flavor

- (a) Same display name ("PepperCheck") across flavors; rely on icon variants only.
- (b) Distinct display names ("PepperCheck", "PepperCheck Staging", "PepperCheck Debug").

**Recommendation:** (b). Distinct bundle IDs mean store review is unaffected; the operator gains immediate visual distinction on the home screen.

#### App Store Connect API key scope

- (a) Admin — broad, riskier if leaked.
- (b) App Manager — sufficient for TestFlight upload, IAP product reads, and ASSN URL configuration.
- (c) Developer — sufficient for build upload only.

**Recommendation:** (b). Minimum scope that still covers IAP and ASSN configuration steps used by setup scripts.

### Decide during a Phase (non-blocking)

#### Crashlytics privacy / consent

Firebase Crashlytics collects device identifiers in crash reports. Revisit the privacy policy (webapp `/privacy`) and the iOS App Store privacy nutrition label as part of Phase 3a.

#### TestFlight tester management

For the staging app, decide who is invited to the internal testing group. Initial assumption: operator only.

#### IAP product visibility in staging and debug builds

- (a) Same UI as production — subscribe button visible, real IAP flow triggered.
- (b) Hide subscribe UI, expose a dedicated "test subscription" UI.

**Recommendation:** (a) for staging (matches production validation). Debug build can either reuse (a) and let the back end reject, or wait for the future debug ergonomics layer (simulated purchase button).

### Deferred (revisit later)

- **Per-flavor app version numbering**: future work; not addressed in Phases 0–3a.
- **Crashlytics alert thresholds**: tune after Phase 3a goes live with real data.
- **Cron job env gating**: revisit only if assumptions change.
- **Debug ergonomics features (simulated purchase, etc.)**: independent future spec; can be authored once Phase 1 lands.

## References

### Existing design docs

- `docs/superpowers/specs/2026-05-05-ios-firebase-config-design.md` — single-bundle-ID iOS Firebase configuration (PR #401 merged; this roadmap continues from there).
- `docs/superpowers/specs/2026-05-09-ios-iap-design.md` — iOS IAP integration design.
- `docs/superpowers/specs/2026-03-30-google-play-iap-design.md` — Google Play IAP design.
- `docs/superpowers/specs/2026-05-06-recommend-payout-topup-design.md` — payout top-up recommendation.
- `docs/plans/2026-02-25-deployment-flow-design.md` — existing deployment flow (migration to `docs/superpowers/specs/` is a separate PR).

### GitHub issues

To be closed by this roadmap:

- [#398](https://github.com/cloveclovedev/peppercheck/issues/398) — iOS push notifications (absorbed into Phase 1).
- [#399](https://github.com/cloveclovedev/peppercheck/issues/399) — Firebase iOS per-flavor split (absorbed into Phase 1).
- [#288](https://github.com/cloveclovedev/peppercheck/issues/288) — Play Store publishing (superseded by a new Phase 2 issue).

Cross-referenced:

- [#400](https://github.com/cloveclovedev/peppercheck/issues/400) — developer-docs restructure (out of scope).

### Project conventions

- `.claude/rules/supabase-workflow.md`
- `.claude/rules/edge-functions.md`
- `.claude/rules/release-branch-tag-workflow.md`
- `.claude/rules/notification-keys.md`
- (new) `.claude/rules/multi-environment-setup.md`

### External documentation

- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Google Play Developer API](https://developers.google.com/android-publisher)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Supabase Management API](https://supabase.com/docs/reference/api)
- [Stripe CLI](https://stripe.com/docs/stripe-cli)

## Revision log

| Date | Change |
|---|---|
| 2026-05-11 | Initial draft. |
| 2026-05-11 | Clarify issue layout: umbrella decomposes into a flat list of task-cluster issues sized to roughly one PR each; Phases are doc-only structural groupings, not GitHub issues. |
