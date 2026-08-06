# Evidence Image Viewer Design

Date: 2026-04-28
Related issues: #369 (deferred follow-up: dynamic thumbnail sizing)

## Goal

Polish the evidence image display in the Flutter app so that submitted evidence photos:

1. Have rounded corners consistent with other thumbnails in the app.
2. Can be tapped to open a near-fullscreen viewer with a semi-transparent black backdrop, with swipe navigation between multiple images.

## Scope

In scope:
- Read-only "submitted evidence" view in `peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_submission_section.dart` (around line 421-443)

Out of scope:
- Edit-form thumbnails (already 64x64 with `AppSizes.radiusSmall` rounded corners — visually consistent between existing assets and newly-picked images, no change needed)
- Submission-form thumbnails (same reasoning)
- Dynamic thumbnail sizing to fit a single row → tracked in #369
- Pinch-to-zoom inside the fullscreen viewer (not a stated requirement; can be added later by wrapping the image in `InteractiveViewer` if desired)

## Changes to existing read-only view

Current code (line 421-443) renders evidence images via `Wrap` with `Image.network(width: 100, height: 100, fit: BoxFit.cover)` and no rounded corners.

Two modifications:

1. Wrap the `Image.network` (and the placeholder `Container` for null-URL fallback) in `ClipRRect(borderRadius: BorderRadius.circular(AppSizes.radiusSmall))`. This matches the 8px radius already used by edit-form thumbnails (line 255-259, 308).
2. Wrap each image with a `GestureDetector` that calls `Navigator.of(context).push(...)` to open `_FullscreenImageViewer` with the full list of evidence URLs and the tapped index.

Images with `asset.publicUrl == null` (the `Icon(Icons.image)` placeholder branch) are not tappable — there is nothing to display in fullscreen for them.

## New widget: `_FullscreenImageViewer`

Private `StatefulWidget` defined in the same file (`evidence_submission_section.dart`). Not extracted to `common_widgets/` because it is currently used in exactly one place and its signature is tailored to evidence images (URL list + initial index). If a second consumer appears, extract then.

### Constructor

```dart
_FullscreenImageViewer({
  required List<String> imageUrls,
  required int initialIndex,
});
```

### Structure

```
PageRoute (opaque: true, fullscreenDialog: true)
└─ Scaffold(backgroundColor: Colors.black87)
   └─ Stack
      ├─ GestureDetector(behavior: HitTestBehavior.opaque, onTap: pop)
      │  └─ PageView.builder
      │     └─ Image.network(
      │          fit: BoxFit.contain,
      │          loadingBuilder: centered CircularProgressIndicator,
      │          errorBuilder: centered Icon(broken_image, white),
      │        )
      ├─ SafeArea: top-right close button (Icon(Icons.close, white))
      └─ SafeArea: bottom-center "X / Y" indicator (only when imageUrls.length > 1)
```

### Behavior

- **Open**: tap any thumbnail in the read-only view.
- **Close**: tap the close button, tap anywhere on the viewer (since the `GestureDetector` wraps the `PageView`, taps on both the dimmed area and the image itself dismiss), or use the Android back gesture/button. The close button exists as an explicit affordance for users who do not realize tap-to-close is available.
- **Navigate**: horizontal swipe via `PageView`. Single-image case still uses `PageView` for simplicity — swipe is a no-op.
- **Backdrop**: `Colors.black87` for the semi-transparent black appearance.
- **Indicator**: `Text("${currentIndex + 1} / ${imageUrls.length}")` updated via `PageController` listener. Hidden entirely when there is only one image.
- **Loading state**: `loadingBuilder` shows a centered `CircularProgressIndicator` until the image decodes.
- **Error state**: `errorBuilder` shows a centered `Icon(Icons.broken_image, color: Colors.white)`.
- **System UI**: no manipulation of status bar / navigation bar. `SafeArea` keeps the close button and indicator out of system inset regions.

### State

- `_pageController: PageController` initialized with `initialPage: initialIndex`
- `_currentIndex: int` initialized to `initialIndex`, updated on `_pageController.addListener`

`dispose` removes the listener and disposes the controller.

## Dependencies

No new package dependencies. Implementation uses only Flutter standard widgets (`Scaffold`, `PageView.builder`, `Image.network`, `SafeArea`, `GestureDetector`, `ClipRRect`).

## Testing

Manual verification on Android emulator after implementation:

- Tap a thumbnail → fullscreen viewer opens with the tapped image centered.
- Swipe left/right → adjacent evidence image displayed; "X / Y" indicator updates.
- Tap close button → viewer dismisses.
- Tap outside the image (dimmed area) → viewer dismisses.
- Press Android back → viewer dismisses.
- Single-image case → no indicator shown, swipe is a no-op.
- Slow network → loading spinner visible.
- Broken URL → broken-image icon visible.
- Submitted view thumbnails have rounded corners matching the edit-form thumbnails.

Build verification:

```bash
cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart 2>&1 | tail -10
```

No widget tests are added — the existing `evidence_submission_section.dart` has no test coverage and adding scaffolding for one viewer is out of scope for a UI polish PR.

## Out of scope / deferred

- **Dynamic thumbnail sizing** (always one row regardless of count): tracked in #369. Tap-to-zoom makes smaller thumbnails acceptable, so this can be evaluated separately.
- **Pinch-to-zoom inside the fullscreen viewer**: not requested. If added later, wrap the `Image.network` in `InteractiveViewer` — about 5 lines of change.
- **Hero animation** between thumbnail and fullscreen image: not requested. Not needed for the MVP polish.
