# iOS Scheme + xcconfig Per-Flavor Split

**Date:** 2026-06-13
**Status:** Draft
**Type:** Implementation spec — Phase 1 task 1.2 / 1.3 (Issue #424)

## Goal

Split the iOS `Runner.xcodeproj` into three flavors (`dev` / `staging` / `production`) so each flavor carries its own bundle ID, home-screen display name, Firebase configuration, and Google Sign-In OAuth client. After this change, the three flavors install side-by-side on one iOS Simulator and each launches into its own Firebase project.

This is the iOS counterpart to the Android product-flavor split shipped in PR #448. Together they complete the bundle-ID-per-flavor and Firebase-per-project portion of Phase 1 in [`2026-05-11-multi-environment-setup-roadmap-design.md`](2026-05-11-multi-environment-setup-roadmap-design.md).

## In scope

- Three Xcode schemes (`dev` / `staging` / `production`) committed under `xcshareddata/xcschemes/`. The scheme name must equal the `--flavor` value case-insensitively (Flutter's lookup is `sentenceCase(flavor).toLowerCase() == schemeName.toLowerCase()`), so a `Runner-`-prefixed scheme would not be recognized.
- Nine build configurations (`Debug-<flavor>` / `Release-<flavor>` / `Profile-<flavor>`) replacing the existing three (`Debug` / `Release` / `Profile`) across the project, the Runner target, and the RunnerTests target.
- A single-layer xcconfig structure under `ios/Flutter/`: three flavor base xcconfigs (committed) carrying the per-flavor settings (bundle ID suffix, display name, GID client ID via gitignored secrets, Firebase plist selector), plus nine combined leaves (committed) where each leaf directly includes the per-configuration Pods xcconfig, `Generated.xcconfig`, and the flavor base.
- `Info.plist` parameterization: `CFBundleDisplayName`, `GIDClientID`, and the Google Sign-In `CFBundleURLSchemes` entry become xcconfig variables.
- A Run Script Phase that copies `Runner/Firebase/GoogleService-Info-<Flavor>.plist` into `Runner/GoogleService-Info.plist` at the start of every build.
- `scripts/setup/bootstrap-ios-secrets.sh` to write the initial `ios/Flutter/Secrets/<Flavor>.secrets.xcconfig` files (all three flavors share the production OAuth client ID for now).
- `.gitignore` entry for `ios/Flutter/Secrets/*.secrets.xcconfig`.
- The resulting `project.pbxproj` diff committed.

## Out of scope

- **Per-env OAuth client creation** — tracked in #427 (Phase 1 task 1.9). Until #427 lands, all three flavors point at the production OAuth client. On Android this means Google Sign-In fails on dev/staging because Google strictly checks `package name + signing-key SHA-1`. On **iOS** the equivalent check (registered bundle ID) is **not strictly enforced** by Google at OAuth time — the security model for iOS clients relies on URL-scheme routing + PKCE, not bundle-ID identity. In combination with local Supabase having the production OAuth `client_id` registered as its accepting client, dev iOS Sign-In actually succeeds. Staging/production iOS Sign-In behavior depends on the matching Supabase project's Google provider configuration. Net: iOS Sign-In may keep working incidentally before #427, which does NOT mean the environment is properly isolated; #427 is still required for correct per-env audience separation.
- **Apple Connect / TestFlight, provisioning profiles, distribution certificates, iOS CI deploy** — tracked in #425 (iOS reshape) and Phase 2.
- **Per-flavor app icon variants** — Phase 1 task 1.12, separate Issue.
- **`firebase_options.dart` per-flavor variants** — single-bundle design in [`2026-05-05-ios-firebase-config-design.md`](2026-05-05-ios-firebase-config-design.md) plus the new Run Script Phase covers what we need.
- **`.vscode/launch.json` `flutterFlavor` keys** — already added by PR #456 (merged before this spec lands).
- **CI workflow changes** — iOS deploy is not yet automated; nothing in `deploy-beta.yml` / `deploy-production.yml` is modified.
- **Real-device verification** — Simulator-only verification is sufficient for the issue acceptance criteria. Apple Developer Portal bundle ID registration is therefore not required by this PR.

## Background

### Current iOS project layout

- Three build configurations on the project (`Debug` / `Release` / `Profile`), wired through the Runner target with `baseConfigurationReference` pointing at `Flutter/Debug.xcconfig` (debug) and `Flutter/Release.xcconfig` (release + profile).
- One shared scheme (`Runner.xcscheme`) covering all four actions.
- `Info.plist` hard-codes `CFBundleDisplayName = "Peppercheck Flutter"`, `GIDClientID = <prod OAuth client ID>`, and the matching `CFBundleURLSchemes` entry.
- `Runner/GoogleService-Info.plist` is gitignored; PR #448 pre-positioned `Runner/Firebase/GoogleService-Info-{Dev,Staging,Production}.plist` (also gitignored) so iOS can switch Firebase configs as soon as the build system grows the wiring.

### Why a copy script instead of per-configuration file references

Xcode's `PBXResourcesBuildPhase` resolves each `PBXFileReference` to a single fixed path; xcconfig variables are not expanded in that path, so the standard "one resource reference per build configuration" approach used elsewhere (e.g., for `INFOPLIST_FILE`) does not extend to arbitrary plists. The well-trodden workaround across the Firebase + Flutter community is a Run Script Phase that copies the correct flavor plist into a stable path *before* `Copy Bundle Resources` runs. The existing single reference to `Runner/GoogleService-Info.plist` stays, the script just rewrites the bytes per build.

This pattern also keeps the Crashlytics dSYM upload script (introduced in Phase 3a, [`#430`](https://github.com/cloveclovedev/peppercheck/issues/430)) happy because it reads from `$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist` — a stable, configuration-agnostic path.

### Why CapCase schemes but lowercase build-config suffixes

Flutter's `xcode_backend.sh` matches a build configuration name as the literal `<Mode>-<flavor>` (where `<flavor>` is exactly what was passed to `--flavor`), so `Debug-dev` is required if `--flavor dev` is to find the configuration. Scheme names are matched the same way: the Flutter tool computes `sentenceCase(flavor).toLowerCase()` and looks for a scheme whose name lowercases to the same string. So `--flavor dev` finds a scheme named `dev` (or `Dev`), but it does NOT find `Runner-Dev` — the `Runner-` prefix breaks the equality check. Both scheme and build-config names therefore use the lowercase flavor names (`dev` / `staging` / `production`), matching the Android `productFlavors { create("dev") }` convention.

## Design

### xcconfig structure (single-layer)

```
ios/Flutter/
  ▸ existing — preserved
    Generated.xcconfig             # Flutter-generated, gitignored

  ▸ existing — removed by this PR
    Debug.xcconfig                 # superseded by the combined leaves below
    Release.xcconfig

  ▸ new — flavor base (committed)
    Dev.xcconfig
    Staging.xcconfig
    Production.xcconfig

  ▸ new — combined leaf (committed, 3-line includes only)
    Debug-dev.xcconfig
    Debug-staging.xcconfig
    Debug-production.xcconfig
    Release-dev.xcconfig
    Release-staging.xcconfig
    Release-production.xcconfig
    Profile-dev.xcconfig
    Profile-staging.xcconfig
    Profile-production.xcconfig

  ▸ new — secrets (gitignored)
    Secrets/Dev.secrets.xcconfig
    Secrets/Staging.secrets.xcconfig
    Secrets/Production.secrets.xcconfig
```

#### Why single-layer, not the original two-layer plan

An earlier draft proposed a two-layer structure with mode bases (`Debug.xcconfig`, `Release.xcconfig`, `Profile.xcconfig`) factoring out the Pods include + Generated, and combined leaves stacking `mode + flavor`. That doesn't work in practice: CocoaPods generates **one** `Pods-<target>.<configname>.xcconfig` per build configuration, named after the exact lowercase config name. After this PR's migration the config names are `Debug-dev` / `Debug-staging` / ... — so CocoaPods emits `Pods-Runner.debug-dev.xcconfig` / `Pods-Runner.debug-staging.xcconfig` / ..., and no `Pods-Runner.debug.xcconfig` exists. A mode base referencing the now-absent `Pods-Runner.debug.xcconfig` via `#include?` would silently match nothing, and the build would fail at link time with missing search paths and OTHER_LDFLAGS. Pulling the Pods include down into each leaf removes the entire abstraction without losing anything — the single shared piece (`Generated.xcconfig`) is just nine duplicate one-liners, which is fine.

#### Flavor base example: `Dev.xcconfig`

```
// Bundle identification
BUNDLE_ID_SUFFIX = .dev
PRODUCT_BUNDLE_IDENTIFIER = dev.cloveclove.peppercheck$(BUNDLE_ID_SUFFIX)

// Home-screen display name (referenced from Info.plist as $(APP_DISPLAY_NAME))
APP_DISPLAY_NAME = PepperCheck Dev

// Firebase plist selector (consumed by the Run Script Phase)
FIREBASE_PLIST_FLAVOR = Dev

// Google Sign-In OAuth client (sourced from gitignored secrets file)
#include? "Secrets/Dev.secrets.xcconfig"
```

`Staging.xcconfig` mirrors this with `BUNDLE_ID_SUFFIX = .staging`, `APP_DISPLAY_NAME = PepperCheck Staging`, and `FIREBASE_PLIST_FLAVOR = Staging`. `Production.xcconfig` uses an empty `BUNDLE_ID_SUFFIX`, `APP_DISPLAY_NAME = PepperCheck`, and `FIREBASE_PLIST_FLAVOR = Production`.

#### Combined leaf example: `Debug-dev.xcconfig`

```
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug-dev.xcconfig"
#include "Generated.xcconfig"
#include "Dev.xcconfig"
```

That is the entire file. Each of the nine combined xcconfigs is three `#include` lines and nothing else — the first picks up the per-configuration CocoaPods settings, the second pulls in Flutter's generated variables, and the third applies flavor-specific overrides (bundle ID, display name, Firebase plist selector, GID client ID via the gitignored secrets include).

#### Secrets file example: `Secrets/Dev.secrets.xcconfig` (gitignored)

```
GID_CLIENT_ID = 768821537635-ltijulfn8brsvv3lm7fe5b51s3i1up6r.apps.googleusercontent.com
GID_REVERSED_CLIENT_ID = com.googleusercontent.apps.768821537635-ltijulfn8brsvv3lm7fe5b51s3i1up6r
```

All three secrets files initially carry the production OAuth client ID. #427 replaces the dev and staging files with their own per-env client IDs and extends `bootstrap-ios-secrets.sh` to pull the right values from a non-committed source.

### Project build configurations

Replace the existing three project-level configurations with nine. Each new configuration inherits its `buildSettings` block from the corresponding mode (the existing `Debug` / `Release` / `Profile` buildSettings are duplicated unchanged into the three flavor variants).

| New project config | buildSettings source |
|---|---|
| `Debug-{dev,staging,production}` | existing project `Debug` config |
| `Release-{dev,staging,production}` | existing project `Release` config |
| `Profile-{dev,staging,production}` | existing project `Profile` config |

### Runner target build configurations

Each of the nine target-level configurations references the matching combined xcconfig:

| Configuration | `baseConfigurationReference` |
|---|---|
| `Debug-dev` | `Flutter/Debug-dev.xcconfig` |
| `Debug-staging` | `Flutter/Debug-staging.xcconfig` |
| `Debug-production` | `Flutter/Debug-production.xcconfig` |
| `Release-dev` | `Flutter/Release-dev.xcconfig` |
| `Release-staging` | `Flutter/Release-staging.xcconfig` |
| `Release-production` | `Flutter/Release-production.xcconfig` |
| `Profile-dev` | `Flutter/Profile-dev.xcconfig` |
| `Profile-staging` | `Flutter/Profile-staging.xcconfig` |
| `Profile-production` | `Flutter/Profile-production.xcconfig` |

`PRODUCT_BUNDLE_IDENTIFIER` is removed from the target-level `buildSettings` blocks (the xcconfig provides it). All other inline settings are duplicated across the three flavors per mode, identical to today.

### RunnerTests target build configurations

The XCTest target carries the same nine configuration names — Xcode synchronizes the configuration list across all targets in a project. Each test configuration keeps its existing `Pods-RunnerTests.<mode>.xcconfig` `baseConfigurationReference`; the three flavor variants share one Pods config per mode:

| Configuration | `baseConfigurationReference` |
|---|---|
| `Debug-{dev,staging,production}` | `Pods-RunnerTests.debug.xcconfig` |
| `Release-{dev,staging,production}` | `Pods-RunnerTests.release.xcconfig` |
| `Profile-{dev,staging,production}` | `Pods-RunnerTests.profile.xcconfig` |

`PRODUCT_BUNDLE_IDENTIFIER` stays at `dev.cloveclove.peppercheck.RunnerTests` for all nine. Tests run against whichever Runner.app is built; the test target itself does not need a flavor suffix.

### Schemes

Three new shared schemes, one per flavor:

| Scheme | Run / Test / Analyze | Profile | Archive |
|---|---|---|---|
| `dev.xcscheme` | `Debug-dev` | `Profile-dev` | `Release-dev` |
| `staging.xcscheme` | `Debug-staging` | `Profile-staging` | `Release-staging` |
| `production.xcscheme` | `Debug-production` | `Profile-production` | `Release-production` |

Each scheme builds the Runner target plus the RunnerTests target, mirroring the structure of the current `Runner.xcscheme`. The existing `Runner.xcscheme` is deleted.

`xcshareddata/xcschememanagement.plist` is intentionally not committed (it is per-user); Xcode regenerates it on first open. The default scheme on first open is whichever Xcode picks alphabetically, which is `dev` — desirable.

### `Info.plist` parameterization

Three values become xcconfig variables; everything else stays as it is today.

| Key | Before | After |
|---|---|---|
| `CFBundleDisplayName` | `Peppercheck Flutter` | `$(APP_DISPLAY_NAME)` |
| `GIDClientID` | hard-coded production client ID | `$(GID_CLIENT_ID)` |
| `CFBundleURLSchemes[0]` | hard-coded reversed client ID | `$(GID_REVERSED_CLIENT_ID)` |

Note: `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)` and `CFBundleExecutable = $(EXECUTABLE_NAME)` already use variable references and are unchanged.

### Run Script Phase: inject Firebase GoogleService-Info.plist

Inserted into the Runner target's build phases immediately after `[CP] Check Pods Manifest.lock`, before `Sources`:

- **Name:** `Inject Firebase GoogleService-Info.plist`
- **Shell:** `/bin/sh`
- **Input files:** `$(SRCROOT)/Runner/Firebase/GoogleService-Info-$(FIREBASE_PLIST_FLAVOR).plist`
- **Output files:** `$(SRCROOT)/Runner/GoogleService-Info.plist`
- **Script body:**

```sh
set -e
SRC="${SRCROOT}/Runner/Firebase/GoogleService-Info-${FIREBASE_PLIST_FLAVOR}.plist"
DST="${SRCROOT}/Runner/GoogleService-Info.plist"
if [ ! -f "$SRC" ]; then
  echo "error: $SRC not found — run scripts/setup/register-firebase-apps.sh first" >&2
  exit 1
fi
cp "$SRC" "$DST"
```

Declaring Input / Output files lets Xcode skip the phase on incremental rebuilds and satisfies the User Script Sandboxing requirement. The existing `PBXFileReference` and `PBXResourcesBuildPhase` entry for `Runner/GoogleService-Info.plist` stay as they are; the script just rewrites the file in place at the start of every build.

### Bootstrap script: `scripts/setup/bootstrap-ios-secrets.sh`

Run once after `git clone` to populate the three secrets xcconfigs with the initial all-production-client values:

```sh
#!/bin/bash
# Bootstrap ios/Flutter/Secrets/*.secrets.xcconfig with the production OAuth client ID.
# All three flavors share the production client until per-env OAuth clients land in #427;
# on Android dev/staging Sign-In will fail (SHA-1 mismatch); on iOS it may succeed
set -euo pipefail
cd "$(dirname "$0")/../../peppercheck_flutter/ios/Flutter"
mkdir -p Secrets

GID_CLIENT_ID="768821537635-ltijulfn8brsvv3lm7fe5b51s3i1up6r.apps.googleusercontent.com"
GID_REVERSED="com.googleusercontent.apps.768821537635-ltijulfn8brsvv3lm7fe5b51s3i1up6r"

for FLAVOR in Dev Staging Production; do
  cat > "Secrets/$FLAVOR.secrets.xcconfig" <<EOF
GID_CLIENT_ID = $GID_CLIENT_ID
GID_REVERSED_CLIENT_ID = $GID_REVERSED
EOF
done
echo "Wrote 3 secrets xcconfigs in $(pwd)/Secrets/"
```

### `.gitignore`

Add to `peppercheck_flutter/.gitignore`:

```
# iOS xcconfig secrets (GID client IDs per flavor)
ios/Flutter/Secrets/*.secrets.xcconfig
```

### Files changed summary

| Path | Change |
|---|---|
| `peppercheck_flutter/ios/Runner.xcodeproj/project.pbxproj` | 9 build configurations on project + Runner + RunnerTests, 1 new Run Script Phase, scheme refs updated, `Runner.xcscheme` ref removed |
| `peppercheck_flutter/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner-{Dev,Staging,Production}.xcscheme` | 3 new files |
| `peppercheck_flutter/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | deleted |
| `peppercheck_flutter/ios/Flutter/Debug.xcconfig` | deleted (superseded by combined leaves) |
| `peppercheck_flutter/ios/Flutter/Release.xcconfig` | deleted (same) |
| `peppercheck_flutter/ios/Flutter/{Dev,Staging,Production}.xcconfig` | 3 new files |
| `peppercheck_flutter/ios/Flutter/{Debug,Release,Profile}-{dev,staging,production}.xcconfig` | 9 new files |
| `peppercheck_flutter/ios/Runner/Info.plist` | 3 keys parameterized |
| `peppercheck_flutter/.gitignore` | secrets glob added |
| `scripts/setup/bootstrap-ios-secrets.sh` | new |

## Verification

VSCode debug — `.vscode/launch.json` already carries `flutterFlavor` on each entry (PR #456). Open one of `Flutter: Dev (Local)` / `Flutter: Staging (Debug)` / `Flutter: Production`, pick an iOS Simulator from the device selector, and run `Start Debugging`.

CLI build-only check (used by future CI):

```sh
cd peppercheck_flutter
flutter build ios --debug   --flavor dev        -t lib/main_dev.dart        --no-codesign
flutter build ios --release --flavor staging    -t lib/main_staging.dart    --no-codesign
flutter build ios --release --flavor production -t lib/main_production.dart --no-codesign
```

### Acceptance matrix

| Scheme / `--flavor` | Expected runtime behavior on iOS Simulator |
|---|---|
| `dev` | Bundle ID `dev.cloveclove.peppercheck.dev`, home-screen name `PepperCheck Dev`, Firebase initializes against `peppercheck-dev` project. Google Sign-In: succeeds against local Supabase (whose Google provider is configured with the production iOS OAuth `client_id`); Google's iOS OAuth check does not strictly enforce the registered bundle ID, so the production `client_id` is accepted even from the `.dev` bundle. This is incidental — proper per-env separation lands with #427. |
| `staging` | Bundle ID `.staging`, `PepperCheck Staging`, Firebase against `peppercheck-staging`. Local runtime requires `.env.staging` to carry BETA Supabase values (operator decision per PR #448); without them, the app builds and installs but the app body shows a white screen because Supabase init throws before the first frame. CI-driven `beta/v*` builds carry the real values. |
| `production` | Bundle ID unchanged, `PepperCheck` (renamed from `Peppercheck Flutter`), Firebase against `peppercheck`, Google Sign-In succeeds. |
| All three installed at once | Three icons coexist on one Simulator's home screen |
| CLI build commands above | All three exit zero |

### Production display name change

The home-screen label on production changes from `Peppercheck Flutter` to `PepperCheck`, matching the marketing name and aligning with the staging / dev labels. This is a visible change for current production users but is a documented intent of the multi-environment roadmap.

## Follow-ups

### New issues filed alongside this work

1. **clone-to-build onboarding inventory** — Inventory and document every step a new contributor must complete after `git clone` to produce a successful three-flavor build (Apple Developer Portal bundle ID registration, Firebase config download per env, iOS secrets bootstrap, Android keystore, `.env.<env>` provisioning, Supabase local stack, etc.). Output is one runbook page under `developer-docs/`.
2. **CLI dev flow** — Provide a `flutter run`-based development path (without VSCode), including per-flavor `Makefile` targets or helper scripts and a quickstart in `developer-docs/`.

### Added to existing issues

3. **#427 (per-env OAuth client)** — Extend `scripts/setup/bootstrap-ios-secrets.sh` to populate per-env GID client IDs from a non-committed source (env var, `~/.config/peppercheck-secrets/`, or Google Cloud OAuth API). With per-env values in place, dev and staging Google Sign-In start working again.
4. **#425 (iOS reshape)** — Already covers APNs Auth Key upload, Apple Connect app creation, provisioning profile / distribution certificate provisioning, and iOS CI deploy automation (Phase 1 task 1.8 and Phase 2 tasks 2.1–2.16); no additional scope from this spec.

## References

- [`2026-05-11-multi-environment-setup-roadmap-design.md`](2026-05-11-multi-environment-setup-roadmap-design.md) — umbrella roadmap, Phase 1 tasks 1.2 and 1.3.
- [`2026-06-05-android-flavor-split-design.md`](2026-06-05-android-flavor-split-design.md) — Android counterpart shipped in PR #448.
- [`2026-05-05-ios-firebase-config-design.md`](2026-05-05-ios-firebase-config-design.md) — earlier single-bundle Firebase iOS config (PR #401), the baseline this design extends.
- GitHub issues: [#424](https://github.com/cloveclovedev/peppercheck/issues/424) (this spec), [#425](https://github.com/cloveclovedev/peppercheck/issues/425) (iOS reshape), [#427](https://github.com/cloveclovedev/peppercheck/issues/427) (per-env OAuth), [#418](https://github.com/cloveclovedev/peppercheck/issues/418) (umbrella).
- PR [#456](https://github.com/cloveclovedev/peppercheck/pull/456) — `.vscode/launch.json` `flutterFlavor` keys (independent merge).
