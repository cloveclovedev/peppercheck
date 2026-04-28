# Profile Edit (Username + Avatar) Design

Date: 2026-04-29
Related follow-up: GitHub issue to be created — refactor `TaskRefereesSection` to rename for tasker view and display referee username/avatar (see Section 8).

## Goal

Add a profile editing surface so users can set a personalized username and avatar image. This unblocks future social-recognition features in task-detail screens (who is refereeing this task) by ensuring meaningful identity data exists per user.

The current state is that `profiles.username` and `profiles.avatar_url` are both `NULL` for every user, because `handle_new_user()` only inserts an `id` and there is no UI to populate these fields.

## Scope

In scope:

- New `ProfileHeaderSection` at the top of `ProfileScreen` showing avatar + username + an edit button.
- Username editing via an `AlertDialog` (using existing `BaseDialog` wrapper).
- Avatar editing via tap on the avatar (image picker → cropper → upload).
- Auto-generated username (`user_xxxxxxxx`, 8 hex chars) for new users via `handle_new_user()`.
- Backfill migration to populate existing rows where `username IS NULL`, then mark `username NOT NULL`.
- DB-level length constraint (`CHECK char_length(username) BETWEEN 2 AND 20`).
- `generate-upload-url` Edge Function extension for `kind: 'avatar'`.

Out of scope (deferred to follow-up issue):

- Refactoring `TaskRefereesSection` (rename for tasker, display referee username/avatar).
- Avatar deletion / reset to placeholder (YAGNI; only change is supported).
- Camera capture (gallery only, matching evidence upload pattern).
- Splitting `username` into separate handle / `display_name` columns (YAGNI; `username` serves both roles in v1).
- Cleanup of old avatar files in R2 when replaced (YAGNI; storage cost is negligible at current scale).
- Profanity / reserved-name filtering on usernames.

## Architecture

### Layered breakdown

```
[ProfileScreen]
  └─ [ProfileHeaderSection]            ← new widget
        ├─ tap avatar → image_picker → image_cropper → ProfileEditController.pickCropAndUpdateAvatar
        └─ tap edit button → showDialog(BaseDialog) → ProfileEditController.updateUsername

[ProfileEditController] (Riverpod AsyncNotifier, new)
  └─ ProfileRepository.updateUsername / updateAvatar (extension of existing repo)
        ├─ direct UPDATE on profiles (RLS gates ownership)
        └─ for avatar: generate-upload-url → R2 PUT → UPDATE avatar_url
```

### Why this shape

- `ProfileHeaderSection` is its own widget so the header can grow later (email, plan info, stats) without bloating `ProfileScreen`.
- `ProfileEditController` is separate from `TimezoneController` because it handles user-initiated mutations with full async/error UX, whereas `TimezoneController` runs an automatic check on profile load. Mixing them would conflate two distinct lifecycles.
- Direct `UPDATE` (not RPC) for username and avatar URL matches the existing `ProfileRepository.updateTimezone` pattern. RLS already enforces ownership; an RPC layer would only add boilerplate without security benefit.

## UI

### Layout

```
ProfileScreen
└─ ProfileHeaderSection (new, single horizontal row)
   │
   │  ┌─────────────────────────────────────────────────────┐
   │  │  ⬤ avatar 64dp     username text         [✎ 編集]   │
   │  │   └─ 📷 badge bottom-right                          │
   │  └─────────────────────────────────────────────────────┘
   │
└─ RefereeAvailabilitySection (existing)
└─ RefereeBlockedDatesSection (existing)
└─ SupportSection (existing)
└─ AccountActionsSection (existing)
```

- Avatar: `CircleAvatar` with `radius: AppSizes.avatarSizeLarge / 2 = 32`. Camera badge overlay in the bottom-right corner provides a visual affordance for "tap to change" (LINE/Slack/Twitter convention).
- Avatar size token: add `static const double avatarSizeLarge = 64.0` to `AppSizes`. Existing `baseCardIconSize = 20.0` stays unchanged for inline list-row avatars.
- Section height: ~88dp (avatar 64 + section vertical padding 12+12), comparable to other sections, not visually empty.

### Username edit dialog

Triggered by the section's edit button. Uses `BaseDialog` (which wraps `AlertDialog`):

- Title: "ユーザー名"
- Content: `TextField` prefilled with current username, `maxLength: 20`, hint "2〜20文字"
- Actions: [キャンセル, 保存]
- Save button shows `CircularProgressIndicator` while `state.isLoading`; TextField and Cancel disabled during save
- Validation errors render inline below the TextField (red text, second line)

### Avatar edit flow

1. Tap avatar (or its camera badge) → `image_picker.pickImage(source: ImageSource.gallery)`
2. If user cancels picker: no-op
3. If image selected → `ImageCropper.cropImage(...)` with circular mask, 1:1 aspect, 512×512 max, JPEG quality 85
4. If user cancels cropper: no-op
5. Loading overlay on avatar (semi-transparent + spinner) while uploading
6. On success: avatar refreshes from new `avatar_url`
7. On failure: SnackBar with localized error

## Data layer

### DB schema changes

`supabase/schemas/profile/tables/profiles.sql`:

- Add `CHECK (char_length(username) BETWEEN 2 AND 20)` constraint named `profiles_username_length_check`.
- Mark `username NOT NULL` (after backfill, sequenced inside the migration).

`supabase/schemas/auth/functions/handle_new_user.sql` — replace the `INSERT INTO public.profiles (id) VALUES (NEW.id);` with a retry loop:

```sql
DECLARE
  v_username TEXT;
  v_attempts INT := 0;
BEGIN
  LOOP
    v_username := 'user_' || encode(gen_random_bytes(4), 'hex');  -- 8 hex chars
    BEGIN
      INSERT INTO public.profiles (id, username) VALUES (NEW.id, v_username);
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_attempts := v_attempts + 1;
      IF v_attempts >= 5 THEN RAISE; END IF;
    END;
  END LOOP;
  -- ... existing inserts (notification_settings, user_ratings, point_wallets, trial_point_wallets, trial_point_ledger)
END;
```

The `4 bytes = 8 hex chars` choice gives ~4.29B unique values; collision risk is negligible but the retry handles the edge case defensively.

### Backfill migration

After `supabase db diff -f add_username_autogen_and_constraints` generates the schema diff, manually append (with `-- DML, not detected by schema diff`):

1. Loop over `profiles WHERE username IS NULL`, generate `user_xxxxxxxx` per row with the same retry pattern.
2. `ALTER TABLE public.profiles ALTER COLUMN username SET NOT NULL`.

The order matters: backfill must succeed before NOT NULL is applied.

### Edge Function changes

`supabase/functions/generate-upload-url/index.ts`:

- Make `task_id` optional in `UploadRequest`.
- Add `kind: 'avatar'` branch:
  - Skip task ownership check (no `task_id` present).
  - Use authenticated `user.id` for path generation.
- Extend `generateR2Key`:
  - `case 'evidence'`: existing `evidence/{YYYY-MM-DD}/{uuid}.{ext}` path (unchanged).
  - `case 'avatar'`: `avatar/{user_id}/{uuid}.{ext}` (singular, flat — matches `evidence/...` naming convention).
- `MAX_FILE_SIZE = 5MB` is shared and ample for cropped avatars (typical output ~50–100KB JPEG).

### Repository extensions

`peppercheck_flutter/lib/features/profile/data/profile_repository.dart`:

```dart
Future<void> updateUsername(String userId, String username) async {
  try {
    await _supabase
      .from('profiles')
      .update({'username': username})
      .eq('id', userId);
  } on PostgrestException catch (e) {
    if (e.code == '23505') throw UsernameAlreadyTakenException();
    rethrow;
  }
}

Future<void> updateAvatar(String userId, XFile cropped) async {
  // 1. Call generate-upload-url with kind: 'avatar'
  // 2. PUT bytes to R2 presigned URL
  // 3. UPDATE profiles.avatar_url = public_url
}
```

`UsernameAlreadyTakenException` is a new exception class in the same file or a sibling errors file.

### Riverpod controller

New file: `peppercheck_flutter/lib/features/profile/presentation/profile_edit_controller.dart`.

Pattern matches existing project controllers (`evidence_controller.dart`, `timezone_controller.dart`):

```dart
@riverpod
class ProfileEditController extends _$ProfileEditController {
  @override
  FutureOr<void> build() {}

  Future<void> updateUsername({
    required String username,
    required VoidCallback onSuccess,
  }) async {
    final trimmed = username.trim();
    final validationError = _validateUsername(trimmed);
    if (validationError != null) {
      state = AsyncError(validationError, StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(currentUserProvider);
      await ref.read(profileRepositoryProvider).updateUsername(user.id, trimmed);
      ref.invalidate(currentProfileProvider);
      onSuccess();
    });
  }

  Future<void> pickCropAndUpdateAvatar({required VoidCallback onSuccess}) async {
    // image_picker → image_cropper → repository.updateAvatar → invalidate
  }

  String? _validateUsername(String value) {
    if (value.length < 2) return /* tooShort key */;
    if (value.length > 20) return /* tooLong key */;
    if (_emojiRegex.hasMatch(value)) return /* emoji key */;
    return null;
  }
}
```

Notes:

- Method names use suffixes (`updateUsername`, `updateAvatar`) — `update` alone collides with `AsyncClassModifier.update` (see `.claude/rules/flutter.md`).
- `ref.invalidate(currentProfileProvider)` triggers a refetch so the header reflects the new value.
- The controller owns image picking and cropping rather than the widget, keeping presentation thin.
- The experimental Riverpod 3.0 `Mutation` API is **not** used: existing project controllers all follow the `AsyncNotifier + state = AsyncLoading + AsyncValue.guard` pattern, and consistency outweighs the experimental upside.

## Validation

### Username (app-side)

| Rule | Behavior | Error i18n key |
|---|---|---|
| Trim leading/trailing whitespace | Apply silently | — |
| Length ≥ 2 | Reject otherwise | `profile.edit.errors.tooShort` |
| Length ≤ 20 | Reject otherwise | `profile.edit.errors.tooLong` |
| No emoji | Regex excludes UTF-16 surrogate pairs / Variation Selectors / Emoji_Presentation codepoints | `profile.edit.errors.emoji` |
| Same as current value | Skip API call, treat as success (close dialog) | — |

### Username (DB-side defense)

- `CHECK (char_length(username) BETWEEN 2 AND 20)` — defense-in-depth length guard.
- `UNIQUE (username)` already exists; uniqueness violations propagate as `PostgrestException` code `23505`, mapped to `UsernameAlreadyTakenException` in the repository.

Emoji exclusion is intentionally app-side only: DB-level emoji regex is locale-dependent and brittle.

### Avatar

- Validation is implicit in the cropper output (always 512×512 JPEG, well under 5MB).
- `ALLOWED_CONTENT_TYPES` in the Edge Function already includes `image/jpeg`.
- Gallery permission denial → SnackBar prompting Settings.

## i18n

Keys are aligned with DB column names (`username`, not `nickname`) for cross-layer clarity.

`assets/i18n/ja.i18n.json` (and corresponding `en.i18n.json`):

```json
"profile": {
  "header": {
    "editUsernameButton": "編集"
  },
  "edit": {
    "usernameTitle": "ユーザー名",
    "usernameHint": "2〜20文字",
    "cropTitle": "切り抜き",
    "save": "保存",
    "cancel": "キャンセル",
    "errors": {
      "tooShort": "2文字以上で入力してください",
      "tooLong": "20文字以内で入力してください",
      "emoji": "絵文字は使えません",
      "taken": "このユーザー名は既に使われています",
      "uploadFailed": "画像のアップロードに失敗しました",
      "galleryPermission": "設定から写真へのアクセスを許可してください",
      "generic": "エラーが発生しました。しばらくしてからお試しください"
    }
  }
}
```

Japanese label is "ユーザー名" (matches Twitter / GitHub / Discord Japanese UI convention; native Japanese composite preferred over `ユーザーネーム` katakana loanword).

## Dependencies

- New: `image_cropper` (latest stable). Provides circular-mask crop UI plus built-in resize and JPEG compression in one call. Existing `image_picker` is reused for gallery selection.
- No other new packages.

## Testing

### pgTAP tests — `supabase/tests/database/profile_username.test.sql` (new)

| Test | Expectation |
|---|---|
| `handle_new_user` produces a username matching `^user_[0-9a-f]{8}$` | match |
| Forced UNIQUE collision recovers via retry | success on a different generated value |
| INSERT with `username = NULL` raises NOT NULL violation | exception |
| INSERT with username length 1 or 21 raises CHECK violation | exception |
| INSERT with username length 2 or 20 succeeds | success |
| Duplicate username INSERT raises UNIQUE violation | exception (existing behavior re-asserted) |
| RLS: a different user cannot UPDATE another user's `username` or `avatar_url` | exception (existing policy re-asserted) |

After all changes pass, run the full pgTAP test suite (per `.claude/rules/db-testing.md`) to verify no regressions.

### Edge Function check

- Local: `supabase functions serve generate-upload-url`, then curl with `kind: 'avatar'` (no `task_id`) and verify the response contains `r2_key` matching `avatar/{user_id}/<uuid>.<ext>`.
- Existing `kind: 'evidence'` calls must continue to work unchanged.

### Flutter check

- `cd peppercheck_flutter && flutter build apk --debug -t lib/main_debug.dart` for compile verification (per `.claude/rules/flutter.md`).
- Single-PR scope, so a final emulator pass at the end covers the full flow:
  - New signup → `ProfileScreen` shows `user_xxxxxxxx` and avatar placeholder.
  - Edit button → dialog → save valid username → reflected in header.
  - Edit with duplicate / too-short / too-long / emoji values → inline error.
  - Avatar tap → gallery picker → cropper → upload → header reflects new image.
  - Cropper cancel → no-op.
  - Existing-user backfill produced a `user_xxxxxxxx` value (verify against a seed user).

## Migration sequence

1. Edit `supabase/schemas/profile/tables/profiles.sql` (add CHECK constraint).
2. Edit `supabase/schemas/auth/functions/handle_new_user.sql` (retry loop).
3. Verify both schema files are listed in `supabase/config.toml` under `[db.migrations]`.
4. `supabase db diff -f add_username_autogen_and_constraints` to generate the migration.
5. Manually append to the generated migration (with `-- DML, not detected by schema diff`):
   - Backfill loop for `username IS NULL` rows.
   - `ALTER COLUMN username SET NOT NULL`.
6. User runs `./scripts/db-reset-and-clear-android-emulators-cache.sh` to verify the migration history applies cleanly from scratch (per `.claude/rules/db-reset.md`; destructive op deferred to user per memory).

## Follow-up issue

To be created via `gh issue create` after this PR is merged:

- **Title**: `Refactor task detail "Request" section: rename for tasker, show referee username/avatar`
- **Body** outline:
  - Background: `TaskRefereesSection` is currently shared between tasker and referee but is information-poor for the tasker (only avatar placeholder + status badge).
  - Changes:
    - Rename section title from "リクエスト" to "レフリー" in tasker view (i18n key gated by viewer role).
    - Display `referee.username` next to the avatar in the section's row.
    - Review whether the referee-side view should still show all referee requests for the task, or only the current user's own request.
  - Depends on this PR (profile editing) being merged so meaningful usernames/avatars exist to display.
  - References this design doc.
