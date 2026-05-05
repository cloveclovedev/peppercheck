# iOS Firebase Configuration

- Issue: [#397](https://github.com/cloveclovedev/peppercheck/issues/397)
- Date: 2026-05-05
- Status: Draft

## Goal

Make the PepperCheck Flutter app start successfully on iOS Simulator and let a user sign in with Google. This unblocks all iOS manual verification, which has been impossible since the iOS build pipeline came alive in #396.

## Background

`Firebase.initializeApp()` is called without options at `peppercheck_flutter/lib/app/app_startup.dart:40`. On Android this works because `peppercheck_flutter/android/app/google-services.json` is present and the `com.google.gms.google-services` Gradle plugin wires it in at build time. On iOS the equivalent file `GoogleService-Info.plist` has never existed in the project, so the app crashes at startup with `FirebaseException ([core/not-initialized] Firebase has not been correctly initialized.)`.

The crash was hidden until now because iOS `pod install` was failing on the deployment-target mismatch addressed in #395 / #396. With the iOS build pipeline now functional, this is the next blocker.

## Scope

### In scope

- Provision the iOS Firebase config file and bundle it into the iOS app.
- Document the per-developer setup workflow for both platforms.
- Verify on iOS Simulator that the app starts and a user can sign in with Google.

### Out of scope (spun off as separate issues)

- iOS push notifications (Capabilities, APNs Auth Key, on-device verification).
- Per-flavor Firebase iOS apps and bundle IDs (debug / staging / production split).
- Reorganization of `developer-docs/` for the v1.0.0 release.

## Approach

### Native config file, not FlutterFire CLI

Use the native `GoogleService-Info.plist` workflow rather than running `flutterfire configure` to generate `lib/firebase_options.dart`. This mirrors the existing Android setup, keeps the two platforms symmetric, and requires no Dart code change. The current `Firebase.initializeApp()` call (no arguments) is correct: the `firebase_core` iOS plugin reads the bundled plist and calls `FirebaseApp.configure()` internally.

The FlutterFire CLI option remains available as a future migration path if web support, type-safe initialization, or per-flavor Firebase projects become priorities.

### Single Firebase iOS app, single bundle ID

Register one iOS app in the existing Firebase project with bundle ID `dev.cloveclove.peppercheck`, matching Android. The Flutter "flavors" (`debug` / `staging` / `production`) are entry-point + `.env` selection only — there are no Gradle product flavors or Xcode build configurations that produce different bundle IDs today. Splitting per flavor is tracked as a separate issue.

### Standard Xcode file reference, committed via pbxproj diff

Add `GoogleService-Info.plist` to the Runner target via Xcode's standard "drag into project" flow. The drag is a one-time imperative action whose result — file reference + Resources build phase entries in `ios/Runner.xcodeproj/project.pbxproj` — is committed and becomes the declarative source of truth. After the diff lands, every developer just needs the plist file at the path; no further Xcode interaction is required.

A more declarative alternative (Podfile `post_install` hook adding a Run Script Build Phase via the `xcodeproj` gem) was considered but rejected as additional complexity for marginal benefit on a one-time setup.

### iOS-only verification scope

Verification covers Firebase initialization (app boots past the crash) and Google Sign-In (user reaches the home screen via Supabase auth). Push notifications, deep smoke testing, and on-device verification are out of scope.

## Components

### A. Firebase Console (manual, per-developer)

The maintainer registers an iOS app in their Firebase project:

- Bundle ID: `dev.cloveclove.peppercheck`
- App nickname: `PepperCheck iOS` (or any value)
- App Store ID: blank
- Skip the SDK install / AppDelegate / build verification steps shown by the console — `firebase_core` handles equivalent initialization automatically.

Download `GoogleService-Info.plist` and place it at `peppercheck_flutter/ios/Runner/GoogleService-Info.plist`. The file is gitignored (matching the existing `google-services.json` policy) and never enters the repository.

### B. Xcode project (one-time pbxproj change, committed)

Open `peppercheck_flutter/ios/Runner.xcworkspace` and drag `GoogleService-Info.plist` from Finder into the Project navigator under the `Runner` group:

- "Copy items if needed": OFF (the file is already in place)
- "Add to targets: Runner": ON

Xcode writes a file reference and a Resources build phase entry into `ios/Runner.xcodeproj/project.pbxproj`. Commit that diff.

### C. Dart code (no change)

`peppercheck_flutter/lib/app/app_startup.dart` is left as-is. The existing `Firebase.initializeApp()` (no arguments) and the comment that already documents the platform config files are both correct.

`peppercheck_flutter/ios/Runner/AppDelegate.swift` is also unchanged. Adding an explicit `FirebaseApp.configure()` call is unnecessary because the `firebase_core` Flutter plugin performs the equivalent native initialization before any Dart code runs.

### D. iOS Info.plist (conditional)

If iOS Simulator verification (Section "Verification") shows that Google Sign-In completes successfully without further changes, no Info.plist edit is needed. The current setup uses the Web client ID for `GIDClientID` and a matching URL scheme, which is appropriate for obtaining an `idToken` to authenticate with Supabase.

If sign-in fails after the plist is bundled, append the iOS OAuth client URL scheme by adding `REVERSED_CLIENT_ID` (from `GoogleService-Info.plist`) to `CFBundleURLTypes` in `peppercheck_flutter/ios/Runner/Info.plist`. Keep the existing Web client URL scheme — both can coexist.

### E. Documentation

Create `developer-docs/modules/ROOT/pages/flutter/firebase-setup.adoc` describing how each developer obtains and places the Firebase config files for both iOS and Android. The page is project-agnostic: it instructs the reader to provision their own Firebase project, never references a specific project ID, and uses the bundle ID / package name from source as the canonical defaults.

Outline:

- Why the file is needed and gitignored
- Prerequisites (Firebase Console access, own Firebase project)
- iOS steps (register app → download plist → place at path)
- Android steps (register app → download json → place at path)
- Verification (`flutter run` and what failure looks like)

Add the page to `developer-docs/modules/ROOT/nav.adoc`. Add a cross-link from `iOS-setup.adoc` so the physical-device guide points to the Firebase prerequisite.

## Verification

All steps run on iOS Simulator (iPhone 15 or similar, iOS 17+) with local Supabase running.

1. Build: `cd peppercheck_flutter && flutter build ios --debug --simulator -t lib/main_debug.dart` succeeds.
2. Bundle inspection: `find build/ios/iphonesimulator -name GoogleService-Info.plist` finds the plist inside the built `.app`.
3. Run: `flutter run -t lib/main_debug.dart -d <simulator-id>` starts past the previous `FirebaseException` and reaches the login screen.
4. Sign-in: tapping Google sign-in opens the auth sheet, completes auth, and lands on the home screen.

Expected outcomes:

- Steps 1–4 all pass → ship.
- Step 3 passes but step 4 fails → apply the Section D Info.plist change and re-run step 4.
- Step 3 fails → the plist is not in the bundle; revisit Section B (target membership).

### Regression on Android

Android receives no source changes in this PR. Confirm with `git diff` that nothing under `peppercheck_flutter/android/` is modified, then run `./scripts/db-reset-and-clear-android-emulators-cache.sh` followed by `flutter run -t lib/main_debug.dart -d <android-id>` to confirm the existing Android startup and sign-in still work.

## Files changed

- `peppercheck_flutter/ios/Runner.xcodeproj/project.pbxproj` — file reference + Resources build phase for `GoogleService-Info.plist` (added by Xcode when the file is dragged in)
- `developer-docs/modules/ROOT/pages/flutter/firebase-setup.adoc` — new page (content per Section E)
- `developer-docs/modules/ROOT/nav.adoc` — entry for the new page
- `developer-docs/modules/ROOT/pages/flutter/iOS-setup.adoc` — cross-link to the Firebase setup page in the prerequisites section
- `peppercheck_flutter/ios/Runner/Info.plist` — conditional, only if verification step 4 fails

Files explicitly NOT changed:

- `peppercheck_flutter/lib/app/app_startup.dart`
- `peppercheck_flutter/ios/Runner/AppDelegate.swift`
- Anything under `peppercheck_flutter/android/`

## Spin-off issues to file

1. `feat(flutter): enable iOS push notifications` — Push Notifications and Background Modes (remote notifications) capabilities, APNs Auth Key in Firebase Console, on-device verification.
2. `refactor(flutter): split Firebase iOS app per flavor` — Per-flavor bundle IDs via Xcode Build Configurations, per-flavor `GoogleService-Info.plist` selection at build time, equivalent on Android via Gradle product flavors.
3. `docs(developer-docs): restructure for v1.0.0 release` — Audit the page tree, retire stale areas (e.g., `docs/development/android/` from the pre-Flutter Kotlin attempt), and align with the v1.0.0 surface.
