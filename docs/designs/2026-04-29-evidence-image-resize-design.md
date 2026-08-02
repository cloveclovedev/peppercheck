# Evidence Image: Auto-Resize Before Upload

**Date:** 2026-04-29
**Status:** Approved

## Context

Evidence image upload currently fails with a hard error dialog when the file exceeds 5MB. The 5MB limit is enforced server-side in the `generate-upload-url` Edge Function (`supabase/functions/generate-upload-url/index.ts:31`), and the client (`evidence_repository.dart`) sends the original picked file as-is.

Modern smartphone photos routinely exceed 5MB:

- iPhone HEIC: 1–3 MB, but iOS may produce JPEG variants that are 3–6 MB
- Android JPEG: typically 3–8 MB on flagship cameras

The avatar upload flow already handles this via `image_cropper` (`avatar_edit_controller.dart:32-37`), which crops to 512×512 / JPEG 85% before upload. Evidence has no equivalent normalization step.

## Decision

Normalize evidence images on the client side before upload. Always re-encode to JPEG quality 85% with longest side ≤ 2048px. If the result still exceeds 5MB, retry with smaller dimensions. Keep the server-side 5MB limit as a safety net.

This guarantees that uploads fit within 5MB in the vast majority of cases, removes the HEIC compatibility concern (HEIC → JPEG is automatic), and improves perceived UX with progress feedback.

## Design

### 1. Normalization pipeline

A new class `ImageNormalizer` encapsulates the pipeline.

**Location:** `peppercheck_flutter/lib/features/evidence/data/image_normalizer.dart`

**Responsibility:** take an `XFile`, return a `NormalizedImage(bytes, filename, mimeType)` ready for R2 upload.

**Algorithm:**

```
for (longestSide, quality) in [(2048, 85), (1536, 85), (1024, 85)]:
    encoded = compress(originalBytes, longestSide, quality)
    if encoded.length <= 5 MB:
        return NormalizedImage(encoded, "<basename>.jpg", "image/jpeg")
throw ImageTooLargeException
```

Smaller source images are not upscaled — `flutter_image_compress` honors original dimensions when they are below the target. They are still re-encoded to JPEG for output uniformity (and to convert HEIC).

The encode function is injected via the constructor (`EncodeFn`) so that fallback branches can be unit-tested without large fixture images:

```dart
typedef EncodeFn = Future<Uint8List> Function(Uint8List bytes, int longestSide, int quality);

class ImageNormalizer {
  ImageNormalizer({EncodeFn? encode}) : _encode = encode ?? _defaultEncode;
  final EncodeFn _encode;
  // ...
}
```

### 2. Library: `flutter_image_compress`

New dependency added to `pubspec.yaml`. Chosen over the alternatives because:

- Native iOS / Android implementation, fast
- Supports HEIC → JPEG conversion (critical for iPhone users)
- Allows fine-grained control of dimensions and quality per call (required for the 3-step fallback)

Alternatives considered and rejected:
- `image_picker`'s built-in `imageQuality` / `maxWidth`: only one pass, cannot retry with smaller dimensions
- `image` package (pure Dart): no HEIC support

### 3. Filename and MIME rewrite

The Edge Function validates that the file extension matches `content_type` (`generate-upload-url/index.ts:35-48`). After normalization, the basename is preserved but the extension is forced to `.jpg`, and `content_type` is sent as `image/jpeg`. Edge Function code is unchanged.

### 4. EvidenceRepository

`_uploadImages` (`evidence_repository.dart:17-69`) is updated to:

1. Call `ImageNormalizer.normalize(image)` instead of reading bytes directly
2. Use the normalized `bytes`, `filename`, and `mimeType` for the Edge Function request and the R2 PUT
3. Accept progress callbacks (`onPreparing(current, total)`, `onUploading(current, total)`) and invoke them at the appropriate points

### 5. EvidenceController state

State type changes from `AsyncValue<void>` to `AsyncValue<EvidenceSubmissionState>`:

```dart
@freezed
class EvidenceSubmissionState with _$EvidenceSubmissionState {
  const EvidenceSubmissionState._();
  const factory EvidenceSubmissionState.idle() = _Idle;
  const factory EvidenceSubmissionState.preparing({
    required int current,
    required int total,
  }) = _Preparing;
  const factory EvidenceSubmissionState.uploading({
    required int current,
    required int total,
  }) = _Uploading;

  bool get isLoading => switch (this) {
    _Idle() => false,
    _Preparing() || _Uploading() => true,
  };
}
```

State transitions during a 3-image submit:

```
.idle()
→ .preparing(1, 3) → .uploading(1, 3)
→ .preparing(2, 3) → .uploading(2, 3)
→ .preparing(3, 3) → .uploading(3, 3)
→ .idle()      // on success
// or AsyncError(...) on failure
```

Applies to all three flows: `submit`, `updateEvidence`, `resubmit`.

### 6. UI changes

In `evidence_submission_section.dart`, render a muted progress text directly below the Submit/Update/Resubmit button (parallel to the existing error display at `evidence_submission_section.dart:659-664`):

```
[Submit button (spinner when isLoading)]
画像を準備中... (2/5)            ← AppColors.textSecondary, smaller font
```

Hidden when state is `.idle()` or `AsyncError`.

For single-image submissions, the count suffix is omitted.

### 7. i18n strings (slang)

New keys under `task.evidence`:

| Key | Japanese (example) |
|---|---|
| `preparing` | 画像を準備中... |
| `preparingMulti` | 画像を準備中... ({current}/{total}) |
| `uploading` | アップロード中... |
| `uploadingMulti` | アップロード中... ({current}/{total}) |
| `error.imageTooLarge` | 画像のサイズが大きすぎます。別の画像を選んでください。 |
| `error.imageProcessingFailed` | 画像の処理に失敗しました。別の画像を選んでください。 |

Final copy will be confirmed during implementation.

### 8. Errors

| Exception | Where it is thrown | UI message |
|---|---|---|
| `ImageTooLargeException` | After 3-step fallback all > 5MB | `error.imageTooLarge` |
| `ImageProcessingException` | `flutter_image_compress` failure (codec, OOM) | `error.imageProcessingFailed` |
| Existing exceptions | Edge Function / R2 / RPC failures | existing `state.error.toString()` (unchanged) |

Mid-batch failures: behavior unchanged. Already-uploaded R2 objects from earlier images in the same batch may be left orphaned on failure. This is an existing issue and is out of scope for this change.

## Testing

### Unit tests

`peppercheck_flutter/test/features/evidence/data/image_normalizer_test.dart` (new):

- **Normal path:** input fixture image → output ≤ 5MB, longest side ≤ 2048px, MIME `image/jpeg`, filename `*.jpg`
- **Filename extension rewrite:** `photo.heic` → `photo.jpg`
- **Fallback (via `EncodeFn` injection):**
  - step 1 returns 6MB-sized buffer, step 2 returns 4MB → expects step 2's bytes
  - step 1 returns 6MB, step 2 returns 6MB, step 3 returns 4MB → expects step 3's bytes
  - all three steps return > 5MB → expects `ImageTooLargeException`

The injection-based fallback test avoids the difficulty of selecting a real-world fixture image that is still > 5MB after JPEG 85% compression.

### Manual / device verification

- iPhone (HEIC source): submit evidence with a typical photo → succeeds, server receives a JPEG ≤ 5MB
- Android (JPEG source): submit evidence with a typical photo → succeeds
- Large photo (~10MB): triggers fallback to step 2 (verify via logging or R2 file size)
- Multi-image (3–5 photos): progress text shows correct `(current/total)` and transitions correctly between "preparing" and "uploading"

## Out of Scope

- Avatar upload (already handled by `image_cropper`)
- Modifying the server-side 5MB limit
- Cleaning up orphaned R2 images from partial multi-image uploads (existing issue)
- Network error special-casing (existing error display is sufficient)

## Affected files

**New:**
- `peppercheck_flutter/lib/features/evidence/data/image_normalizer.dart`
- `peppercheck_flutter/test/features/evidence/data/image_normalizer_test.dart`

**Modified:**
- `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart`
- `peppercheck_flutter/lib/features/evidence/presentation/controllers/evidence_controller.dart`
- `peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_submission_section.dart`
- `peppercheck_flutter/pubspec.yaml` (add `flutter_image_compress`)
- i18n string files under `peppercheck_flutter/lib/i18n/`
