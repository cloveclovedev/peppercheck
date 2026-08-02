# Non-prod environment banner (Issue #419)

## Context

This spec covers **Phase 0, task 0.1** of the multi-environment setup roadmap
([design doc](./2026-05-11-multi-environment-setup-roadmap-design.md);
[umbrella issue #418](https://github.com/cloveclovedev/peppercheck/issues/418)).
The task is tracked as
[issue #419](https://github.com/cloveclovedev/peppercheck/issues/419).

Until this work lands, a running PepperCheck build gives no on-screen signal
of which environment it is connected to. As Phase 1 introduces per-flavor
bundle IDs, Firebase projects, and Supabase project endpoints, the operator
needs an immediate visual cue distinguishing staging and debug builds from
production. Production builds remain unchanged.

## Goal

Render a low-effort, always-visible environment indicator on every screen of
the Flutter app for non-production flavors, with zero per-screen integration
cost and minimal design footprint.

## Non-goals

- App icon variants per flavor (`#426`, Phase 1).
- Custom-drawn banner widget. We start with Flutter's built-in `Banner`; if
  visual tuning is needed, that is a follow-up.
- Exposing other runtime config (envFile, Supabase host, app version) to the
  widget tree. Only `AppEnvironment` is exposed for now.
- Profile-screen version display (mentioned in brainstorming as a separate
  future task).

## Target state

A flavor-aware ribbon overlays the top-right corner of every screen on
non-production builds:

- `staging` → yellow ribbon, label `STAGING`, color `AppColors.accentYellowLight` (`#FFE474`).
- `debug` → green ribbon, label `DEBUG`, color `AppColors.accentGreenLight` (`#93D2BD`).
- `production` → no ribbon rendered.

The ribbon is rendered via Flutter's built-in `Banner` widget at
`BannerLocation.topEnd`, with default font styling (white, `FontWeight.w900`,
~10pt). The Flutter framework's own debug ribbon
(`debugShowCheckedModeBanner`) is disabled to avoid double-ribbons in local
debug runs.

## Design

### Widget tree

The banner is injected at the `MaterialApp.builder` hook, which wraps the
entire Navigator subtree. This guarantees coverage on every route regardless
of whether the destination screen uses a `Scaffold`.

```
MyApp
└── MaterialApp.router
    ├── debugShowCheckedModeBanner: false
    └── builder: (context, child) => EnvironmentBanner(child: child!)
        └── EnvironmentBanner
            └── (production)  child
            └── (staging)     Banner(color: yellowLight, message: 'STAGING', location: topEnd) → child
            └── (debug)       Banner(color: greenLight,  message: 'DEBUG',   location: topEnd) → child
```

### AppConfig plumbing

The widget needs to read the current environment, but `AppConfig` is
currently only passed into `appStartup()` and never reaches the widget tree.
We bridge this via a focused Riverpod provider.

**Provider boundary.** The provider exposes `AppEnvironment` (the enum) — not
the full `AppConfig` — because the widget tree only needs the runtime
environment value. `AppConfig.envFile` is bootstrap-only data used by
`_initSdk` to load `dotenv` and has no place in the widget surface. Future
runtime config with different consumers (log endpoints, feature flags) gets
its own focused provider rather than being stuffed into a single God object.

**Injection point.** The provider is declared with a `throw
UnimplementedError` body and is overridden once at the root
`ProviderContainer` inside `appStartup`. This is the standard Riverpod
pattern for app-bootstrap values (same shape as the `sharedPreferences`
example in the Riverpod docs). The existing `appStartup` already constructs
a `ProviderContainer` and hands it to `UncontrolledProviderScope`, so the
only structural change is adding an `overrides:` list:

```dart
@Riverpod(keepAlive: true)
AppEnvironment appEnvironment(Ref ref) => throw UnimplementedError(
  'appEnvironmentProvider must be overridden at the root ProviderContainer in appStartup. '
  'See peppercheck_flutter/lib/app/app_startup.dart.',
);
```

```dart
final container = ProviderContainer(
  overrides: [
    appEnvironmentProvider.overrideWithValue(config.environment),
  ],
);
```

`AppConfig` the class is retained as a build-flavor descriptor used by
`appStartup` directly. A one-line docstring clarifies the asymmetry between
the class and the provider:

```dart
/// Build-time descriptor used by [appStartup] during bootstrap only.
/// Widget-facing runtime state lives in `appEnvironmentProvider`.
class AppConfig { ... }
```

### Bootstrap flow

```
main_staging.dart           appStartup(AppConfig.staging)
                                  │
                                  ▼
app_startup.dart            _initSdk(config)                       // dotenv, Firebase, Stripe, Supabase
                            ProviderContainer(
                              overrides: [
                                appEnvironmentProvider
                                  .overrideWithValue(config.environment),   // ★ root injection
                              ],
                            )
                            container.read(fcmServiceProvider).initialize()
                            runApp(UncontrolledProviderScope(
                              container: container,
                              child: MyApp(),
                            ))
                                  │
                                  ▼
app.dart                    MaterialApp.router(
                              builder: (_, child) => EnvironmentBanner(child: child!),
                              debugShowCheckedModeBanner: false,
                              ...
                            )
                                  │
                                  ▼
environment_banner.dart     final env = ref.watch(appEnvironmentProvider);
                            switch (env) { production / staging / debug }
```

## Files changed

| Kind | Path | Change |
|---|---|---|
| Modify | `lib/app/config/app_environment.dart` | Add `appEnvironmentProvider` (codegen, `keepAlive: true`, `throw UnimplementedError`). Add docstring to `AppConfig` class. |
| Modify | `lib/app/app_startup.dart` | Add `overrides: [appEnvironmentProvider.overrideWithValue(config.environment)]` to `ProviderContainer`. |
| New | `lib/common_widgets/environment_banner.dart` | `EnvironmentBanner extends ConsumerWidget`. Switches on `appEnvironmentProvider` and wraps `child` with `Banner` for staging/debug, returns `child` unchanged for production. |
| Modify | `lib/app/app.dart` | Add `builder:` and `debugShowCheckedModeBanner: false` to `MaterialApp.router`. |
| New | `test/common_widgets/environment_banner_test.dart` | Widget tests for the three environment cases. |
| Generated | `lib/app/config/app_environment.g.dart` | Output of `dart run build_runner build`. |

## Testing

### Widget tests (`test/common_widgets/environment_banner_test.dart`)

A `ProviderScope` harness overrides `appEnvironmentProvider`:

```dart
Widget _harness({required AppEnvironment env, required Widget child}) {
  return ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(env),
    ],
    child: MaterialApp(home: EnvironmentBanner(child: child)),
  );
}
```

Three cases:

| Environment | Assertion |
|---|---|
| `production` | `find.byType(Banner)` is `findsNothing`; child is found. |
| `staging` | One `Banner` with `message == 'STAGING'`, `color == AppColors.accentYellowLight`, `location == BannerLocation.topEnd`. |
| `debug` | One `Banner` with `message == 'DEBUG'`, `color == AppColors.accentGreenLight`, `location == BannerLocation.topEnd`. |

Not covered (out of scope by design):

- Pixel-level rendering of Flutter's `Banner` widget (framework-owned).
- `dotenv` / SDK initialization (separate concern).
- Production-build behavior end-to-end (logically covered by the production
  widget test; a real release build is the operator's smoke check).

### Build verification

Per `.claude/rules/flutter.md`:

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

### Manual visual verification

| Flavor | Expected |
|---|---|
| `flutter run -t lib/main_debug.dart` | Green `DEBUG` ribbon in the top-right corner on every screen. No red Flutter debug ribbon. |
| `flutter run -t lib/main_staging.dart` | Yellow `STAGING` ribbon in the top-right corner on every screen. |
| production release build | No ribbon. (Not exercised locally; covered by the production widget test plus operator smoke check on the next production tag.) |

## Acceptance mapping (Issue #419)

| Acceptance criterion | How it is met |
|---|---|
| Banner appears on every screen in staging and debug builds | `MaterialApp.builder` wraps the Navigator subtree, so the banner overlays every route regardless of whether the screen uses a `Scaffold`. Verified by manual visual run; staging/debug widget tests confirm the banner is present in the rendered tree. |
| Banner is absent on production builds | `EnvironmentBanner` switches on `AppEnvironment.production` and returns the child unwrapped. Verified by the `production → findsNothing` widget test. |
| Banner does not overlap critical UI (safe area respected) | Flutter's `Banner` widget renders a diagonal ribbon in the chosen corner without consuming layout space (it overlays, not pushes). `BannerLocation.topEnd` keeps the ribbon away from the bottom navigation. |

## Open follow-ups

- Visual tuning (smaller text, thinner ribbon, dimmer color) is deferred
  until the default ribbon has been seen on real builds. Tracked
  conversationally; no separate issue yet.
- App version display in the Profile screen — out of scope for #419, tracked
  separately when it comes up.
