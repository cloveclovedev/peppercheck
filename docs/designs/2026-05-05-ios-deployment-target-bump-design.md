# iOS Deployment Target Bump to 15.0

Issue: [#395](https://github.com/cloveclove/peppercheck/issues/395)

## Problem

iOS builds fail at the `pod install` stage because `firebase_core` (Dart pkg `^4.3.0`, native pod `FirebaseCore 12.x`) requires a minimum iOS deployment target of 15.0. The Flutter project still targets iOS 13.0 in two places:

- `peppercheck_flutter/ios/Podfile` line 2: `platform :ios, '13.0'` is commented out, so CocoaPods falls back to the default `iOS 13.0`.
- `peppercheck_flutter/ios/Runner.xcodeproj/project.pbxproj`: 3 occurrences of `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` (Debug, Release, Profile build configs at lines 476, 605, 656).

Local iOS verification (simulators and real devices) is currently blocked, which means UI-touching changes cannot be confirmed for iOS / Android parity. Most recently this came up while verifying #394 (bottom nav bar margin fix).

## Goals

- Make `pod install` succeed without errors.
- Make `flutter run` and `flutter build ios` succeed on iOS 15+ simulators.
- Keep the change minimal and reviewable — no related cleanup bundled in.

## Non-Goals

- Bumping beyond 15.0 to "future-proof" against subsequent plugin requirements.
- Downgrading `firebase_core` / other Firebase plugins to retain iOS 13/14 support (rejected: drags in cascading downgrades, drops security patches, only postpones the bump).
- Refactoring or cleaning up unrelated iOS configuration.

## Approach

Edit two files directly. Per Flutter official docs, this is the standard practice — there is no `flutter` CLI command or centralized config that abstracts these settings.

### Changes

1. **`peppercheck_flutter/ios/Podfile`** — uncomment line 2 and set the platform:

   ```ruby
   platform :ios, '15.0'
   ```

2. **`peppercheck_flutter/ios/Runner.xcodeproj/project.pbxproj`** — replace all three occurrences of `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` with `15.0;`. Direct text edit is preferred over Xcode UI so the PR diff is exact and reproducible.

3. **`peppercheck_flutter/ios/Podfile.lock`** — regenerate by running `pod install` from `peppercheck_flutter/ios/`. Commit the resulting lock file.

## Compatibility Impact

iOS 13/14 users are dropped. Real-world impact is negligible:

- iPhone models whose maximum supported OS is iOS 13 or 14 do not effectively exist — the iPhone 6s / SE (1st gen) / 7 family supports up to iOS 15.
- Active users on iOS 13/14 (devices capable of newer iOS but not updated) are typically <1% per Apple's published iOS adoption figures, and Japan's iOS update rate runs higher than the global average.
- PepperCheck is in beta; the user base is small enough that a precise measurement is unnecessary. If desired, Firebase Console → Analytics → OS version breakdown can confirm in minutes.

## Verification

1. `cd peppercheck_flutter/ios && pod install` — completes without the firebase_core deployment-target error.
2. `cd peppercheck_flutter && flutter build ios --debug -t lib/main_debug.dart --no-codesign` — succeeds.
3. Launch the app on an iOS simulator (iPhone 15 and iPhone SE per the issue) and confirm it boots to the home screen.
4. Sanity-check that the Android build is not affected: `flutter build apk --debug -t lib/main_debug.dart`.

## Risks

- **CI**: `.github/workflows/ci-flutter.yml` may pin an older Xcode / iOS simulator runner image. Verify the CI iOS job (if it builds iOS) still passes after the bump.
- **Other plugins**: a follow-on `pod install` may surface other plugins that also want a higher target. If so, they were already incompatible — the bump only made the failure visible, and those would need a separate decision.

## Out of Scope

- Bumping any Firebase plugin versions.
- Touching Android `minSdkVersion` or other unrelated build configuration.
- Cleaning up unrelated commented-out lines in the Podfile.
