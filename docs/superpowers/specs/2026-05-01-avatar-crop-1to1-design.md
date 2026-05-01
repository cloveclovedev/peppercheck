# Avatar Crop: Force 1:1, Hide Aspect Ratio UI

**Date:** 2026-05-01

## Problem

The avatar image cropper at `peppercheck_flutter/lib/features/profile/presentation/avatar_edit_controller.dart` does not constrain the crop to 1:1 as intended:

1. **Initial aspect ratio is the image's original ratio**, not square. Avatars are displayed in a circle, so any non-square crop is visually incorrect.
2. **The aspect ratio picker is still visible** in the cropper UI (bottom controls on Android, picker button on iOS), letting the user switch to other ratios.
3. **The toolbar title shows the literal string `'crop'`** instead of the existing localization `t.profile.edit.cropTitle` ("切り抜き").

Root cause for (1) and (2): the current settings use `aspectRatioPresets: [CropAspectRatioPreset.square]` and `lockAspectRatio: true`, but `initAspectRatio` is not specified, so the cropper defaults to `CropAspectRatioPreset.original` and locks to *that* ratio. The square preset only appears as one option in the picker UI.

## Design

### Change

**`peppercheck_flutter/lib/features/profile/presentation/avatar_edit_controller.dart`** — modify the `cropImage()` call:

- Add top-level `aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1)` to enforce 1:1 across platforms (single source of truth).
- `AndroidUiSettings`:
  - Remove `aspectRatioPresets` and `lockAspectRatio` (made redundant by top-level `aspectRatio`).
  - Add `hideBottomControls: true` to hide the aspect ratio picker row entirely.
  - Replace literal `'crop'` with `t.profile.edit.cropTitle`.
  - Keep `cropStyle: CropStyle.circle`.
- `IOSUiSettings`:
  - Remove `aspectRatioPresets` and `aspectRatioLockEnabled` (made redundant by top-level `aspectRatio`).
  - Add `aspectRatioPickerButtonHidden: true` to hide the picker button.
  - Add `resetAspectRatioEnabled: false` so the iOS reset button cannot revert to original ratio.
  - Replace literal `'crop'` with `t.profile.edit.cropTitle`.
  - Keep `cropStyle: CropStyle.circle`.

### Rotation

Rotation behavior differs by platform because of how `image_cropper` (uCrop on Android, TOCropViewController on iOS) structures its UI:

- **Android:** the rotate slider lives inside the bottom controls strip, alongside the aspect-ratio picker. There is no per-tab visibility flag in `image_cropper` 9.x — `hideBottomControls: true` removes the rotate UI as a side-effect of hiding the aspect-ratio picker. We accept this loss because the user's primary intent is "select the area, nothing else".
- **iOS:** rotate buttons live in the toolbar, independent of the aspect-ratio picker, so they remain visible by default. We do not hide them in this change.

The asymmetry is intentional for now. If iOS rotate becomes a problem during iOS verification, a follow-up PR can add `rotateButtonsHidden: true` to `IOSUiSettings` for consistency.

### Result UX

- User picks an image from the gallery.
- Cropper opens with a circular 1:1 crop overlay covering the image.
- User can pan and zoom to choose which area to use (and rotate on iOS).
- No aspect ratio picker is visible.
- Toolbar title reads "切り抜き".

### Files changed

```
peppercheck_flutter/
  lib/features/profile/presentation/
    avatar_edit_controller.dart   # MODIFY: cropImage() arguments
```

### Tests

Existing tests under `test/features/profile/` exercise the controller's success / error / cancellation paths via mocks; they do not assert on the `cropImage()` argument shape. No new unit tests are added — the change is to native UI configuration and is verified by manual emulator/device checks.

### Manual verification

On both Android and iOS:
- Launch profile edit → tap avatar → pick a non-square image from the gallery.
- Confirm: crop overlay is circular and locked to 1:1; pan/zoom/rotate work; no aspect ratio picker / preset row is visible; toolbar title shows "切り抜き".
- Confirm the saved avatar appears correctly cropped in the profile header.

### Out of scope

- Replacing the `image_cropper` package.
- Changes to upload, storage, or display logic for the avatar.
- Localizing the cropper UI beyond the toolbar title (other labels are platform-default).
