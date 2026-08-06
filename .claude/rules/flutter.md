# Flutter Development

## Build Verification

After modifying Dart source files, verify the app compiles:

```bash
scripts/dev-run.sh --build 2>&1 | tail -10
```

This runs a debug APK compile check with the JDK-21 pin and `--flavor dev`
applied automatically (no backend or emulator). It wraps:

```bash
cd peppercheck_flutter && flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

The project uses flavored entry points (`main_dev.dart`, `main_staging.dart`, `main_production.dart`), not `lib/main.dart`. Pass `--flavor dev` to match the entry point; without a flavor, Gradle builds every flavor and Flutter reports a misleading "failed to produce an .apk file" even on a successful build.

Local Android builds require a JDK ≤ 21; the JDK 25/26 that Android Studio / Homebrew now ship is too new for the pinned Gradle/AGP toolchain. `scripts/dev-run.sh` pins it automatically. See `docs/development/flutter/android-jdk.md`.

## Riverpod Controller Naming

Riverpod's `$AsyncClassModifier` base class defines a protected `update` method:

```dart
Future<ValueT> update(FutureOr<ValueT> Function(ValueT) cb, {FutureOr<ValueT> Function(Object, StackTrace)? onError})
```

**Never name a controller method `update`** in classes extending `_$*Controller` (AsyncNotifier). It will produce an `invalid_override` compile error. Use a domain-specific name instead (e.g., `updateEvidence`, `updateProfile`).

## Spacing Between Widgets

Use `SizedBox` for spacing between sibling widgets in Column/Row. Do NOT use `Padding` with `EdgeInsets.only(bottom:)` or `EdgeInsets.only(top:)` on individual items.

Padding on each item adds unwanted space after the last (or before the first) item, making spacing uneven and harder to adjust.

```dart
// GOOD: SizedBox between items
Column(
  children: [
    WidgetA(),
    const SizedBox(height: AppSizes.spacingSmall),
    WidgetB(),
  ],
)

// BAD: Padding on each item
Padding(
  padding: const EdgeInsets.only(bottom: AppSizes.spacingSmall),
  child: WidgetA(),
),
```

For dynamic lists, use an indexed loop with `if (i > 0) SizedBox(height: ...)` between items.
