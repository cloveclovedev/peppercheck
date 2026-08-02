# Rename `debug` environment to `dev` (Flutter, CI, DX, operator scripts)

**Author:** Makoto Kurihara
**Date:** 2026-06-06
**Status:** Design
**Parent:** [#418](https://github.com/cloveclovedev/peppercheck/issues/418) (multi-environment setup roadmap)
**Implements:** [#445](https://github.com/cloveclovedev/peppercheck/issues/445)
**Blocks:** [#423](https://github.com/cloveclovedev/peppercheck/issues/423), [#424](https://github.com/cloveclovedev/peppercheck/issues/424), [#425](https://github.com/cloveclovedev/peppercheck/issues/425), [#426](https://github.com/cloveclovedev/peppercheck/issues/426), [#427](https://github.com/cloveclovedev/peppercheck/issues/427)

## Summary

Rename the lowest-environment identifier from `debug` to `dev` across the Flutter app, CI workflows, developer-experience surfaces (VSCode launcher, Claude rules), the operator-facing Stripe sandbox setup script, and active reference documentation. Pure rename — no behavior change. The rationale for choosing `dev` (Android Gradle Plugin `debug` `buildType` source-set collision) is recorded in [`2026-06-05-android-flavor-split-design.md`](2026-06-05-android-flavor-split-design.md) §"Flavor names: `dev` / `staging` / `production`".

## Why this is a precursor

Phase 1 of the multi-environment roadmap ([`2026-05-11-multi-environment-setup-roadmap-design.md`](2026-05-11-multi-environment-setup-roadmap-design.md)) fans out per-flavor source-set files (manifests, app icons, Firebase config) into `android/app/src/<flavor>/`. If the lowest flavor is named `debug`, those paths collide with the built-in `debug` `buildType` source set and silently bleed into the `*Debug` variants of every other flavor. The collision is described in detail in the android-flavor-split spec; this rename removes the entire class of footgun before #423 / #424 / #425 / #426 / #427 lock per-flavor file layouts into the repo.

## Scope

### 1. Flutter code

| File | Change |
| --- | --- |
| `peppercheck_flutter/lib/main_debug.dart` | `git mv` → `main_dev.dart`; body `AppConfig.debug` → `AppConfig.dev` |
| `peppercheck_flutter/lib/app/config/app_environment.dart` | enum value `debug` → `dev`; `static const debug` → `static const dev`; `envFile: 'assets/env/.env.debug'` → `'.env.dev'` |
| `peppercheck_flutter/lib/app/config/app_environment.g.dart` | Regenerate via `dart run build_runner build --delete-conflicting-outputs` |
| `peppercheck_flutter/lib/app/app_startup.dart` | Comment at line 45 mentioning `.env.debug` → `.env.dev` |
| `peppercheck_flutter/lib/common_widgets/environment_banner.dart` | `case AppEnvironment.debug:` → `case AppEnvironment.dev:`; banner label `"DEBUG"` → `"DEV"` |
| `peppercheck_flutter/test/common_widgets/environment_banner_test.dart` | `AppEnvironment.debug` → `AppEnvironment.dev`; expected label `"DEBUG"` → `"DEV"` |

### 2. Asset list & env file

| File | Change |
| --- | --- |
| `peppercheck_flutter/pubspec.yaml` (line 104) | Asset path `assets/env/.env.debug` → `.env.dev` |
| `peppercheck_flutter/assets/env/.env.debug` (gitignored) | Operator-side: `mv .env.debug .env.dev` |

### 3. CI workflows

| File | Change |
| --- | --- |
| `.github/workflows/ci-flutter.yml` (line 35) | `touch assets/env/.env.debug` → `.env.dev` |
| `.github/workflows/deploy-beta.yml` (line 147) | Same |
| `.github/workflows/deploy-production.yml` (line 147) | Same |

### 4. Developer-experience surfaces

| File | Change |
| --- | --- |
| `.vscode/launch.json` | Configuration name `"Flutter: Debug (Local)"` → `"Flutter: Dev (Local)"`; `"program": "lib/main_debug.dart"` → `"lib/main_dev.dart"` |
| `.claude/rules/flutter.md` | Build verification example using `main_debug.dart` → `main_dev.dart`; flavored entry-point list mentions |

### 5. Operator-facing script

| File | Change |
| --- | --- |
| `scripts/setup/configure-stripe-debug-sandbox.sh` | `git mv` → `configure-stripe-dev-sandbox.sh`; internal Stripe CLI profile name `cloveclove-debug` → `cloveclove-dev`; all user-facing prompt text "debug sandbox" → "dev sandbox" |

The Stripe CLI profile name change requires the operator to re-run `stripe login --project-name=cloveclove-dev` after pulling the merged PR (the existing `cloveclove-debug` profile in `~/.config/stripe/config.toml` is local and unaffected by the rename — operators may delete it manually if desired).

### 6. Active reference documentation

| File | Change |
| --- | --- |
| `docs/designs/2026-05-11-multi-environment-setup-roadmap-design.md` | Rewrite environment-name `debug` references to `dev` (does not touch Android `debug` `buildType` / Xcode `Debug` configuration / Flutter build-mode `--debug` mentions). Add Revision log entry |
| `docs/designs/2026-05-31-stripe-debug-sandbox-design.md` | Same content rewrite + Revision log entry. **Filename is preserved** as a date-anchored snapshot — see §"Doc handling philosophy" below |
| `developer-docs/modules/ROOT/pages/flutter/initial-local-setup.adoc` | 4 environment-name `debug` references → `dev` |
| `developer-docs/modules/ROOT/pages/flutter/firebase-setup.adoc` | `flutter run -t lib/main_debug.dart` example → `main_dev.dart` |

### 7. PR description — operator checklist

The PR body lists actions the operator performs out-of-band (cannot be tested in CI):

- [ ] R2 bucket `peppercheck-debug` — drop and recreate as `peppercheck-dev` (local-only test data, nothing worth preserving)
- [ ] Local `peppercheck_flutter/assets/env/.env.debug` — `mv` to `.env.dev`
- [ ] Stripe Dashboard — rename sandbox display name `"Debug"` → `"Dev"` (API keys unchanged)
- [ ] Stripe CLI — re-run `stripe login --project-name=cloveclove-dev`
- [ ] GitHub Secrets `DEBUG_*` — none exist (verified via `gh secret list`); record this finding inline
- [ ] Rewrite environment-name `debug` references in issue bodies #418 / #423 / #424 / #425 / #426 / #427 (operator action)

## Doc handling philosophy

A design document's **filename embeds the date it was written** — that is the snapshot anchor. Even when terminology changes later, the filename stays so the document's place in the project's timeline remains stable.

The document's **content** is the current source of truth for what to do or look at. Letting old terminology persist in active reference docs (roadmap, runbooks) causes future operators and contributors to read instructions in a vocabulary that no longer matches the code. So content is kept current, and a Revision log entry records when and why the terminology changed.

- `2026-05-11-multi-environment-setup-roadmap-design.md` and `2026-05-31-stripe-debug-sandbox-design.md` are **active references** consumed by ongoing Phase 1 work and operator runbooks → rewrite content, add Revision log entry, preserve filename
- Closed-feature historical specs and plans (e.g., `2026-05-16-non-prod-environment-banner-design.md`, `2026-04-27-draft-task-deletion-design.md`, legacy `docs/plans/*`) are **snapshots of decisions made at a point in time** → leave untouched

Future readers of the snapshots can read `debug` as the historical name of the environment now called `dev`; the rationale lives in the android-flavor-split spec and is linked from each rewritten doc's Revision log.

## Explicitly out of scope (per #445 §6)

- Android Gradle Plugin's built-in `debug` `buildType` — standard Gradle name, unrelated
- Xcode's standard `Debug` build configuration — standard Xcode name
- Flutter / Dart `--debug` / `--release` / `Debug` / `Release` build-mode flags and macros
- C/C++ `_DEBUG` preprocessor macro (Windows runner)
- Comments and identifiers where "debug" means "build with debug symbols" or "attach a debugger"
- Supabase migration string literals containing `'debug'` (template IDs and unrelated row data)
- Cloudflare Workers `console.debug` / log-level types (`peppercheck-webapp/cloudflare-env.d.ts`)
- `README.md` mentions of `SUPABASE_URL_DEBUG` / `GATEWAY_URL_DEBUG` — these are legacy from the pre-Flutter native Android implementation, not consumed by the current Flutter Gradle build (verified via grep). The README at large is stale and warrants a separate "refresh for Flutter" PR
- Legacy Native Android documentation — removed in the documentation-structure cleanup.

## Verification

Run locally before pushing:

1. `dart run build_runner build --delete-conflicting-outputs` (regenerate `app_environment.g.dart`)
2. `cd peppercheck_flutter && flutter test`
3. `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart` — primary entry point builds
4. `cd peppercheck_flutter && flutter build apk --debug -t lib/main_staging.dart` — staging not regressed
5. `cd peppercheck_flutter && flutter build apk --debug -t lib/main_production.dart` — production not regressed
6. `git ls-files | xargs rg "main_debug|\\.env\\.debug|AppEnvironment\\.debug|AppConfig\\.debug" 2>/dev/null` — returns only intentionally out-of-scope historical doc hits

CI green on the PR confirms `.env.dev` `touch` works in all three workflows.

## PR strategy

Single PR, branch `chore/rename-debug-to-dev-flutter` cut from `main`. Rename is mechanical and atomic — splitting code from docs would land a state where one half references the old name while the other half references the new name, breaking `flutter build` for any reviewer who checks out the intermediate commit.

The PR title follows the project's Conventional Commits convention: `chore(flutter): rename "debug" environment to "dev"`.

In-place work on the feature branch (no `git worktree`): Flutter builds need gitignored secrets / config (`local.properties`, `.env.*`, `google-services.json`) that worktrees don't carry over.

## Risks

- **`.g.dart` regeneration order** — must run `build_runner` after the enum rename or stale generated code will reference `debug`. Mitigation: include the regeneration in step 1 of the verification sequence; `--delete-conflicting-outputs` handles the conflict.
- **Operator local-env break at merge time** — once `main` carries `.env.dev`, any operator pull without renaming their gitignored `.env.debug` will hit `flutter build` failures ("asset not found"). Mitigation: PR description's operator checklist makes the `mv` step explicit; the change is mechanical (one `mv` command).
- **Stripe CLI re-login friction** — operators using the existing `cloveclove-debug` profile must re-login as `cloveclove-dev`. Mitigation: this is one command (`stripe login --project-name=cloveclove-dev`), called out in the operator checklist. The renamed setup script's prompt walks the operator through it.

## Acceptance

- [ ] All §1–§6 file edits applied
- [ ] Verification steps 1–6 pass locally
- [ ] CI green on the PR
- [ ] PR description carries the §7 operator checklist
- [ ] Revision log entries added to roadmap-design.md and stripe-debug-sandbox-design.md

## Revision log

- 2026-06-06: Initial spec for #445.
