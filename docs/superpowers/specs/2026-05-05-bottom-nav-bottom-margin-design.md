# Bottom Navigation Bar Bottom Margin

**Date:** 2026-05-05 (revised after first emulator verification)
**Related issues:** Found during real-device testing on Android (3-button vs gesture navigation)

## Problem

The floating bottom navigation bar in `AppScaffold` looks visibly cramped on Android 3-button navigation and iOS home-button devices: the bar's rounded bottom edge sits only ~4px above the system UI strip (or screen edge). On Android gesture and iOS home-indicator devices, the same 4px gap looks fine because the system UI strip there is a thin gesture line rather than a bulky bar.

## Root cause

Original implementation in `lib/common_widgets/app_scaffold.dart`:

```dart
bottomNavigationBar: SafeArea(
  child: Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.screenHorizontalPadding,  // 16
      vertical: AppSizes.screenVerticalPadding,      // 4
    ),
    child: Container(...),
  ),
),
```

Modern Flutter on Android (target SDK 35+) is edge-to-edge by default. `MediaQuery.padding.bottom` therefore reflects the *height of the system UI strip*, not zero:

| Mode | `MediaQuery.padding.bottom` |
|---|---|
| Android 3-button | ~48dp (system nav bar height) |
| Android gesture | ~24dp (gesture indicator height) |
| iOS home indicator | ~34px |
| iOS home button | 0 |

`SafeArea` consumes that inset by pushing the bar up by exactly that much, so the bar's outer bottom edge ends up at the **top of the system UI strip**. The only visible breathing room above that strip is the `vertical: 4` bottom of the wrapping `Padding`. That 4px feels fine when the strip is a thin line (gesture / home indicator) and feels cramped when the strip is a bulky bar (3-button / home button — though "home button" devices have no inset, so the bar sits 4px from the screen edge, which also feels tight).

The first attempted fix (`SafeArea(minimum: 12)`) was based on the incorrect assumption that `padding.bottom = 0` on 3-button mode, where the `minimum` would have raised the bar by 12px. In reality `padding.bottom = 48` on 3-button mode, so `max(48, 12) = 48` and the `minimum` never kicks in. Combined with dropping the `Padding`'s 4px bottom contribution, the bar ended up flush with the system nav bar (zero gap). This rewrite corrects that.

## Design

Treat the bottom margin as **system inset + breathing room**, not as a single max. The breathing room is the constant gap above whatever system UI strip exists at the bottom:

```
visible margin = MediaQuery.padding.bottom + breathingRoom
```

- On 3-button: `48 + 8 = 56px` total below the bar (8px breathing above the system nav bar).
- On gesture: `24 + 8 = 32px` total (8px above the gesture indicator).
- On iOS home indicator: `34 + 8 = 42px` total (8px above the indicator).
- On iOS home button: `0 + 8 = 8px` total (8px above the screen edge).

Implementation: keep the bare `SafeArea` (which consumes the inset), and set the wrapping `Padding`'s bottom to `breathingRoom` (12px). Apply the same `breathingRoom` term to the scroll-content bottom padding so the last list item never slides behind the bar.

A renamed `AppSizes` constant centralizes the breathing room value. The previous misnamed `bottomNavigationBarMinBottomMargin` is replaced (it was implying `max(...)` semantics that we no longer use).

### Changes

**1. `lib/app/theme/app_sizes.dart`** — add constant

```dart
// Breathing room below the floating bottom navigation bar, applied
// on top of the system safe-area inset. Keeps a visible gap above
// the system nav strip (Android 3-button bar, gesture indicator,
// iOS home indicator) and a non-cramped margin from the screen edge
// on devices with no inset (iOS home button).
static const double bottomNavigationBarBreathingRoom = 8.0;
```

**2. `lib/common_widgets/app_scaffold.dart`** — bare `SafeArea` + `Padding` with `bottom: breathingRoom`

```dart
bottomNavigationBar: SafeArea(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.screenHorizontalPadding,
      AppSizes.screenVerticalPadding,                 // top: 4
      AppSizes.screenHorizontalPadding,
      AppSizes.bottomNavigationBarBreathingRoom,      // bottom: 12
    ),
    child: Container(...),
  ),
),
```

**3. `lib/common_widgets/app_scaffold.dart`** — scroll-content bottom padding adds the same breathing room

```dart
final bottomPadding =
    AppSizes.bottomNavigationBarHeight +
    MediaQuery.paddingOf(context).bottom +
    AppSizes.bottomNavigationBarBreathingRoom;
```

### Resulting margins

Margin = `MediaQuery.padding.bottom + breathingRoom`. The `+4` deltas come from breathing room growing 4 → 8.

| Mode | Original | New | Delta |
|---|---|---|---|
| Android 3-button | ~52px (4px breathing) | ~56px (8px breathing) | +4 |
| Android gesture | ~28px (4px breathing) | ~32px (8px breathing) | +4 |
| iOS home indicator | ~38px (4px breathing) | ~42px (8px breathing) | +4 |
| iOS home button | ~4px (4px breathing) | ~8px (8px breathing) | +4 |

The +4 delta is a deliberate compromise: just enough to ease the cramped feel above the chunky 3-button system nav bar without noticeably altering the already-acceptable gesture/home-indicator look. The constant is the single tuning knob — adjust if real-device viewing suggests another value.

### Files changed

```
peppercheck_flutter/
  lib/app/theme/app_sizes.dart              # ADD: bottomNavigationBarBreathingRoom (replaces ...MinBottomMargin)
  lib/common_widgets/app_scaffold.dart      # MODIFY: bare SafeArea + Padding bottom + scroll bottomPadding
  test/common_widgets/app_scaffold_test.dart  # MODIFY: assertions reflect inset + breathingRoom formula
```

## Verification

- Android 3-button emulator: visible breathing room above the system nav bar (was ~4px, now ~12px).
- Android gesture emulator: bar sits a touch higher than before (28→36px), no regression in usability.
- iOS simulator with home indicator (e.g. iPhone 15): bar sits a touch higher than before (38→46px).
- iOS simulator without home indicator (e.g. iPhone SE): visible 12px gap from screen edge (was ~4px).
- Last item of a long scroll list is fully visible above the bar in all modes.

## Out of scope

- Top padding (`screenVerticalPadding = 4`) of the bar — unchanged.
- Tuning `bottomNavigationBarBreathingRoom` away from `12.0`. May revisit after real-device viewing.
- Per-mode breathing rooms (e.g. smaller in gesture, larger in 3-button). Single value is intentional for simplicity.
