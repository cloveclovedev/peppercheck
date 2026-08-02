# Phase 3a Flutter (Profile & Notification-token client) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Flutter `profile` and `notification` features off the Supabase SDK onto the Go API (via the shared `ApiClient`), restructure both to the Option E layout, add a dedicated presigned-upload client for avatar bytes, and route sign-out through an app-layer coordinator.

**Architecture:** Extends the Phase 2 Flutter client boundary. `ApiClient` (Phase 2, `getJson` only) gains idempotent write verbs. Avatar bytes go to R2 through a new `PresignedUploadClient` (no Firebase bearer). `profile`/`notification` are restructured `data/ domain/ application/ ui/` with `*ViewModel` notifiers, mirroring the already-Option-E `features/auth`. Sign-out ordering (FCM delete → Firebase sign-out) is owned by an app-layer coordinator, not by feature cross-dependencies.

**Tech Stack:** Flutter, Riverpod (codegen), Freezed + json_serializable (DTOs), Dio (inside `core/network` only), GoRouter.

**Spec:** `docs/superpowers/specs/2026-07-25-phase3a-profile-notification-design.md` (§5, §6, D8, D10). **Depends on:** the Phase 3a **backend** plan (endpoints live) and the Phase 2 Flutter merge (`ApiClient`, `AppUser` current-user contract, `me_repository`/`me_dto` pattern, `features/auth` in Option E). Execute this plan **after** both are in place.

## Global Constraints

- **One HTTP client for JSON.** Features call `ApiClient` (`lib/core/network/api_client.dart`); no feature builds its own Dio. Avatar bytes use `PresignedUploadClient` (also `core/network`), never `ApiClient`.
- **Retry policy:** only idempotent GET auto-retries once on 401 (Phase 2). `PATCH`/`POST`/`PUT`/`DELETE` never auto-retry.
- **`supabase_flutter` must not be imported** by `features/profile` or `features/notification` after this plan (CI architecture import check).
- **`firebase_auth` only in `features/auth`** (Phase 2 rule, unchanged). The sign-out coordinator calls the auth feature's sign-out; it does not import `firebase_auth` itself.
- **Option E layout (D8):** `data/<x>_repository.dart` + `data/<x>_dto.dart` (DTOs separate, Freezed); `domain/<model>.dart`; `application/<use_case>.dart`; `ui/<screen>_screen.dart` + `ui/<screen>_view_model.dart` (`*ViewModel` notifier). Follow the existing `features/auth` structure as the template.
- **No `update` method name** on any `AsyncNotifier`-based `*ViewModel` (project rule — `invalid_override`). Use domain-specific names.
- **Profile domain is idless, no Stripe** (matches the Go contract, D10). Other-user profiles are Phase 4.
- **Spacing** uses `SizedBox` (not per-item `Padding`); use `AppSizes` constants, never hardcoded pixels (project rules).
- **Build verification:** each task runs `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`. A **single emulator pass** runs at the end (Task 8), not per task (project convention).

---

## Task 1: Extend `ApiClient` with idempotent write verbs

**Files:**
- Modify: `peppercheck_flutter/lib/core/network/api_client.dart`
- Test: `peppercheck_flutter/test/core/network/api_client_test.dart`

**Interfaces:**
- Produces on `ApiClient`:
  - `Future<Map<String, dynamic>> patchJson(String path, {Object? body})`
  - `Future<Map<String, dynamic>> postJson(String path, {Object? body})`
  - `Future<void> putJson(String path, {Object? body})`
  - `Future<void> deleteJson(String path, {Object? body})`
  - All authenticated; **no auto-retry**; map the error envelope to `ApiException` exactly as `getJson` does; a 2xx with no body is fine for `putJson`/`deleteJson`.

- [ ] **Step 1: Write the failing test**

In `test/core/network/api_client_test.dart` (fake Dio / `DioAdapter` as in the existing ApiClient tests): `patchJson` sends `PATCH` with the bearer + request-id and returns the decoded body on 200; a 409 envelope → `ApiException(code: 'username_taken')`; `postJson` returns body on 200; `putJson`/`deleteJson` succeed on 204; **no retry** happens on a 401 for any of them (assert the adapter saw exactly one call).

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/core/network/api_client_test.dart`
Expected: FAIL (methods undefined).

- [ ] **Step 3: Implement the verbs**

Add a private `_sendBody(method, path, body, {forceRefresh})` that attaches the bearer + `X-Request-Id` and calls `_dio.request` with the given method, then reuse the existing `_mapErrorResponse`/`_mapDioException`. `patchJson`/`postJson` decode and return the object; `putJson`/`deleteJson` return `void` on 2xx. None retry on 401.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/core/network/api_client_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/core/network/api_client.dart test/core/network/api_client_test.dart
git commit -m "feat(flutter): add idempotent write verbs to ApiClient"
```

---

## Task 2: `PresignedUploadClient` (bytes → R2)

**Files:**
- Create: `peppercheck_flutter/lib/core/network/presigned_upload_client.dart`
- Create: `peppercheck_flutter/lib/core/network/presigned_upload_client_provider.dart` (+ `.g.dart` via build_runner)
- Test: `peppercheck_flutter/test/core/network/presigned_upload_client_test.dart`

**Interfaces:**
- Produces: `PresignedUploadClient.put({required String uploadUrl, required List<int> bytes, required String contentType})` → `Future<void>`; throws a plain `UploadFailed` on non-2xx (not `ApiException`). Carries **no** Firebase bearer, runs **none** of the API interceptors, shares only the timeout, and **never logs** the `uploadUrl`.

- [ ] **Step 1: Write the failing test**

`presigned_upload_client_test.dart` (fake Dio): `put` issues a `PUT` to the exact `uploadUrl` with `Content-Type` and `Content-Length` set to the byte length and **no `Authorization` header**; a non-2xx response throws `UploadFailed`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/core/network/presigned_upload_client_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the client + provider**

`presigned_upload_client.dart`: a bare `Dio` (own instance, timeouts only, no interceptors); `put` sets headers `Content-Type` and `Content-Length: bytes.length` and does `dio.putUri(Uri.parse(uploadUrl), data: Stream.fromIterable([bytes]))`; throw `UploadFailed` on non-2xx. Add a Riverpod provider. Run `dart run build_runner build`.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/core/network/presigned_upload_client_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/core/network/presigned_upload_client* test/core/network/presigned_upload_client_test.dart
git commit -m "feat(flutter): add PresignedUploadClient for direct-to-R2 avatar PUTs"
```

---

## Task 3: `profile` DTOs + repository over `ApiClient`

**Files:**
- Create: `peppercheck_flutter/lib/features/profile/data/profile_dto.dart` (+ `.freezed.dart`/`.g.dart`)
- Create: `peppercheck_flutter/lib/features/profile/data/avatar_upload_dto.dart` (+ generated)
- Modify: `peppercheck_flutter/lib/features/profile/domain/profile.dart` (drop `id`, `stripe_connect_account_id`)
- Rewrite: `peppercheck_flutter/lib/features/profile/data/profile_repository.dart` (ApiClient-backed; remove `supabase_flutter`)
- Delete: `peppercheck_flutter/lib/features/profile/data/profile_errors.dart` is kept but `UsernameAlreadyTakenException` is derived from `ApiException(code:'username_taken')`
- Test: `peppercheck_flutter/test/features/profile/data/profile_repository_test.dart`

**Interfaces:**
- Produces:
  - `ProfileDto` (Freezed): `username`, `avatarUrl`, `timezone`, `createdAt`, `updatedAt` → `toDomain()` → `Profile`.
  - `AvatarUploadDto`: `uploadUrl`, `publicUrl`, `expiresAt`.
  - `ProfileRepository` methods (all via `ApiClient`): `fetchOwn()`, `updateUsername(String)`, `updateTimezone(String)`, `requestAvatarUpload({contentType, fileSizeBytes})`, `commitAvatar(String publicUrl)`.
- Consumes: `ApiClient` (Task 1). Mirrors the Phase 2 `features/auth/data/me_repository.dart` + `me_dto.dart` pattern.

- [ ] **Step 1: Write the failing repository test**

`profile_repository_test.dart` (fake `ApiClient`): `fetchOwn` maps `GET /api/v1/me/profile` JSON → `Profile` (no `id` field); `updateUsername` calls `PATCH /api/v1/me/profile {username}` and rethrows `ApiException(code:'username_taken')` as `UsernameAlreadyTakenException`; `requestAvatarUpload` maps the POST response to `AvatarUploadDto`; `commitAvatar` calls `PATCH {avatarUrl}`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/profile/data/profile_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update the domain + write DTOs + repository**

Edit `domain/profile.dart` to the idless, Stripe-less shape (`username`, `avatarUrl`, `timezone`, `createdAt`, `updatedAt`). Create `profile_dto.dart` and `avatar_upload_dto.dart` (Freezed + json_serializable, snake→camel per the JSON contract). Rewrite `profile_repository.dart` to depend on `ApiClient` and implement the five methods; map `ApiException(code:'username_taken')` → `UsernameAlreadyTakenException`. Remove all `supabase_flutter` imports. Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/profile/data/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/features/profile/data lib/features/profile/domain test/features/profile/data
git commit -m "feat(flutter): profile repository + DTOs over ApiClient (no supabase)"
```

---

## Task 4: `profile` Option E restructure — `ui/` + `*ViewModel`

**Files:**
- Move/rename: `lib/features/profile/presentation/` → `lib/features/profile/ui/`
- Rename: `*_controller.dart` → `*_view_model.dart`; classes `*Controller` → `*ViewModel`
- Create: `lib/features/profile/ui/avatar_edit_view_model.dart` uses `PresignedUploadClient` + `ProfileRepository`
- Modify: consumers referencing the old paths/classes (`app_router.dart`, widgets, `current_profile_provider`)
- Test: update `test/features/profile/presentation/*` → `test/features/profile/ui/*`

**Interfaces:**
- Produces: `ProfileViewModel`, `UsernameEditViewModel`, `TimezoneViewModel`, `AvatarEditViewModel` (Riverpod notifiers in `ui/`). Method names are domain-specific (never `update`).
- Consumes: `ProfileRepository` (Task 3), `PresignedUploadClient` (Task 2).

- [ ] **Step 1: Move files and rename classes**

`git mv` each `presentation/*` to `ui/*` with the `_view_model` suffix; rename the notifier classes `*Controller` → `*ViewModel` and their `part`/generated references; move `presentation/widgets` → `ui/widgets`, `presentation/providers/current_profile_provider.dart` → `ui/current_profile_provider.dart` (kept for Task 5). Update all imports across the app (`grep -rn "features/profile/presentation"`).

- [ ] **Step 2: Rewire the avatar view model to the 3-step flow**

`avatar_edit_view_model.dart`: after crop (existing 512×512 jpg), **pre-check bytes ≤ 5 MiB** (else surface a friendly error, no request); call `repo.requestAvatarUpload(contentType:'image/jpeg', fileSizeBytes: bytes.length)` → `presignedUploadClient.put(uploadUrl, bytes, 'image/jpeg')` → `repo.commitAvatar(publicUrl)` → refresh `currentProfileProvider`. On `ApiException(code:'rate_limited')` show a "try again later" message.

- [ ] **Step 3: Update tests to the new paths/classes**

Move `test/features/profile/presentation/*` → `test/features/profile/ui/*`; rename referenced classes; add an `AvatarEditViewModel` test (fake repo + fake `PresignedUploadClient`): happy path calls request→put→commit in order; a > 5 MiB file is rejected **before** any request; `rate_limited` surfaces the retry message.

- [ ] **Step 4: Run to verify build + tests pass**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test test/features/profile/`
Expected: PASS; no dangling `presentation/` imports.

- [ ] **Step 5: Build check + commit**

Run: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10` (expect success).

```bash
cd peppercheck_flutter && git add lib/features/profile test/features/profile lib/app
git commit -m "refactor(flutter): profile feature to Option E ui/ + ViewModel; wire avatar 3-step"
```

---

## Task 5: `currentProfileProvider` via `GET /me/profile`

**Files:**
- Modify: `lib/features/profile/ui/current_profile_provider.dart` (+ generated)
- Test: `test/features/profile/ui/current_profile_provider_test.dart`

**Interfaces:**
- Produces: `currentProfileProvider` (keepAlive) → `Future<Profile>` from `ProfileRepository.fetchOwn()`, gated on the Phase 2 signed-in state; separate from the `AppUser` auth contract (which stays identity-only, D7).

- [ ] **Step 1: Write the failing test**

`current_profile_provider_test.dart` (fake repo, override signed-in state): resolves to the fetched `Profile` when signed in; not fetched when signed out.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/profile/ui/current_profile_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Rewrite `current_profile_provider.dart` to watch the Phase 2 auth-state (signed-in) and call `ref.watch(profileRepositoryProvider).fetchOwn()`; expose an invalidate for the edit view models to call after a successful change. Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/profile/ui/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/features/profile/ui/current_profile_provider* test/features/profile/ui
git commit -m "feat(flutter): currentProfileProvider reads GET /me/profile"
```

---

## Task 6: `notification` token sync over the Go API

**Files:**
- Rewrite: `lib/features/notification/data/notification_repository.dart` (ApiClient; remove `supabase_flutter`)
- Modify: `lib/features/notification/application/fcm_service.dart` (upsert on start/refresh/signed-in via the repo)
- Test: `test/features/notification/data/notification_repository_test.dart`, `test/features/notification/application/fcm_service_test.dart`

**Interfaces:**
- Produces:
  - `NotificationRepository.registerToken(String token, String deviceType)` → `PUT /api/v1/me/fcm-tokens`; `deregisterToken(String token)` → `DELETE /api/v1/me/fcm-tokens`.
  - `FcmService` upserts on app start, `onTokenRefresh`, and the signed-in transition; a signed-out upsert is a **no-op**; the full token is **never logged**.
- Consumes: `ApiClient` (Task 1), the Phase 2 auth-state.

- [ ] **Step 1: Write the failing tests**

`notification_repository_test.dart` (fake `ApiClient`): `registerToken` → `PUT /api/v1/me/fcm-tokens {token, deviceType}`; `deregisterToken` → `DELETE {token}`. `fcm_service_test.dart` (fake repo + fake auth-state): upsert fires on the signed-in transition and on token refresh; **no** upsert while signed out (this removes the Phase 2 P2-5 disable).

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/notification/`
Expected: FAIL.

- [ ] **Step 3: Implement**

Rewrite `notification_repository.dart` on `ApiClient` (derive `deviceType` from `Platform.isAndroid/isIOS`); remove `supabase_flutter`. In `fcm_service.dart`, replace the disabled Supabase-keyed sync with `repo.registerToken(...)` on start/refresh/signed-in; keep the client-side notification **text resolver** unchanged. Never log the token in full.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/notification/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/features/notification test/features/notification
git commit -m "feat(flutter): re-enable FCM token sync via the Go API"
```

---

## Task 7: App-layer sign-out coordinator

**Files:**
- Create: `lib/app/sign_out_coordinator.dart` (+ generated provider)
- Modify: the sign-out call sites (`features/auth/ui/sign_in_view_model.dart` or wherever sign-out is triggered; and `app_router`/settings action)
- Test: `test/app/sign_out_coordinator_test.dart`

**Interfaces:**
- Produces: `SignOutCoordinator.signOut()` that runs legs in order: **(1) `NotificationRepository.deregisterToken(currentToken)`** (best-effort) → (2) `AuthRepository.signOut()` (Firebase). Each leg is independent; a failed FCM delete is logged and **does not** block Firebase sign-out. FCM delete happens **before** Firebase sign-out (so the bearer is still valid).

- [ ] **Step 1: Write the failing test**

`sign_out_coordinator_test.dart` (fake notification repo + fake auth repo): asserts `deregisterToken` is called **before** `authRepo.signOut`; when `deregisterToken` throws, `authRepo.signOut` is **still** called and `signOut()` completes without error.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/app/sign_out_coordinator_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement + rewire call sites**

Create `SignOutCoordinator` (app layer, composition — it depends on both feature repos so the features do not depend on each other). Replace direct `authRepo.signOut()` call sites with `signOutCoordinator.signOut()`. Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/app/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/app test/app lib/features/auth
git commit -m "feat(flutter): app-layer sign-out coordinator (FCM delete before Firebase)"
```

---

## Task 8: CI import checks + full analyze/test + single emulator pass

**Files:**
- Modify: the architecture-import CI check config (extend the Phase 2 check: `supabase_flutter` not imported by `features/profile` or `features/notification`)
- Verify only (no new code)

- [ ] **Step 1: Extend the import-check**

Add `features/profile` and `features/notification` to the CI rule that forbids `supabase_flutter` imports (alongside the Phase 2 `features/auth` rule). Run it locally: `grep -rn "package:supabase_flutter" lib/features/profile lib/features/notification` must be empty.

- [ ] **Step 2: Full analyze + tests + build**

Run:
- `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`
- `cd peppercheck_flutter && dart format --set-exit-if-changed lib test`
- `cd peppercheck_flutter && flutter analyze`
- `cd peppercheck_flutter && flutter test`
- `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

Expected: all PASS.

- [ ] **Step 3: Single emulator verification pass**

With the Go API running (`backend && make up`) and a dev sign-in, verify on the emulator: sign in (provisioning creates the profile with a generated username), view profile, edit username (and the taken-name error), change timezone, upload/replace an avatar (and a > 5 MiB rejection), receive a push (FCM token registered), sign out (FCM token deregistered). Record the result.

- [ ] **Step 4: Commit**

```bash
cd peppercheck_flutter && git add .github
git commit -m "ci(flutter): forbid supabase_flutter in profile/notification features"
```

---

## Self-Review

**Spec coverage (§ → task):** ApiClient write verbs (implied by §6) → T1; PresignedUploadClient §5.1.1 → T2; profile repository/DTO §5.1 → T3; Option E restructure D8/§5.1 → T4; avatar 3-step + client pre-check §4.6/§5.1 → T4; currentProfileProvider §5.1 → T5; notification token sync §5.2 → T6; sign-out coordinator §5.2 → T7; CI import checks + emulator §8 → T8. Gaps: none (backend endpoints are the separate backend plan; other-user profiles / notification-settings editing are out of scope §10).

**Placeholder scan:** Test steps enumerate concrete cases and name the fake to use; the implementer writes full assertions modeled on the cited Phase 2 files (`me_repository_test`, existing ApiClient tests). No `TBD`/`TODO`.

**Type consistency:** `ApiClient.patchJson/postJson/putJson/deleteJson` (T1) are consumed by `ProfileRepository` (T3) and `NotificationRepository` (T6). `PresignedUploadClient.put` (T2) is consumed by `AvatarEditViewModel` (T4). `ProfileRepository.{fetchOwn,updateUsername,updateTimezone,requestAvatarUpload,commitAvatar}` (T3) are consumed by the profile view models (T4) and `currentProfileProvider` (T5). `NotificationRepository.{registerToken,deregisterToken}` (T6) are consumed by `FcmService` (T6) and `SignOutCoordinator` (T7). Consistent.
