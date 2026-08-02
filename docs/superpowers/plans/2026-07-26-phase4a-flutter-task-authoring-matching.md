# Phase 4a Flutter (Task Authoring & Matching Client) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Flutter `task`, `matching`, and `home` features off the Supabase SDK onto the Go API (via the shared `ApiClient`), restructure them to the Option E layout, add a first-class publish verb with a config-bounded referee-count selector (no point-cost UI), migrate task-detail role checks to the Phase 2 `AppUser` contract, and surface async matching results via a shared `core` progressive poller owned by a Riverpod v3 `AsyncNotifier`.

**Architecture:** Extends the Phase 2/3a Flutter client boundary. Features call `ApiClient` (Phase 3a added `postJson`/`patchJson`/`putJson`/`deleteJson`). DTOs are **camelCase**, mirroring the pinned wire contract (backend spec §7.1); task/assignment responses embed a minimal `PublicProfile` (username/avatar). Role decisions read `currentAppUserProvider` (`AppUser.internalUserId`) via a pure domain helper `Task.viewerRole(...)`. Async matching is owned by a `taskDetail` `AsyncNotifier` family that polls with a provider-neutral `core` `pollUntil`, guarding post-`await` writes with `ref.mounted` and cancelling via `ref.onDispose` (Riverpod v3). FCM stays notification-display only.

**Tech Stack:** Flutter, Riverpod **v3.0.3** (codegen `@riverpod`), Freezed + json_serializable (DTOs), Dio (inside `core/network` only), GoRouter, slang (i18n).

**Spec:** `docs/superpowers/specs/2026-07-26-phase4a-flutter-task-authoring-matching-design.md`. **Wire contract (source of truth):** backend spec `docs/superpowers/specs/2026-07-25-phase4a-task-authoring-matching-design.md` **§7.1** (camelCase JSON, embedded `PublicProfile`). **Depends on:** the Phase 4a **backend** (endpoints live, implementing §7.1) and the Phase 3a **Flutter** merge (`ApiClient` write verbs; `AppUser` / `currentAppUserProvider`; the `me_repository`/`me_dto` template). This is **design-ahead**: execute only after both land.

## Global Constraints

- **Wire contract is frozen in backend spec §7.1** (camelCase). DTOs are written test-first against §7.1 — no "confirm the handler later". If a real backend response diverges from §7.1, fix §7.1 (and the DTO) together, not silently.
- **One HTTP client for JSON.** Features call `ApiClient` (`lib/core/network/api_client.dart`); no feature builds its own Dio.
- **`ApiClient` verbs assumed present (Phase 3a):** `Future<Map<String,dynamic>> getJson(String path)`, `postJson(String path,{Object? body})`, `patchJson(String path,{Object? body})`, `Future<void> putJson(...)`, `Future<void> deleteJson(...)`. All map `{error:{code,message,requestId}}` → `ApiException`. Only GET auto-retries once on 401; writes never auto-retry.
- **`supabase_flutter` must NOT be imported** by `features/task`, `features/matching`, or `features/home` after this plan (CI architecture import check).
- **`firebase_auth` only in `features/auth`.** Role checks read `currentAppUserProvider`, never Firebase/Supabase directly.
- **DTOs are camelCase, separate files** (`*_dto.dart`, Freezed + json_serializable); the repository maps DTO ↔ domain; **domain never imports DTOs**. `Task.tasker` / `RefereeRequest.referee` are `PublicProfile?`.
- **`Task` is fee-less, strategy-less; `RefereeRequest` has no `matchingStrategy` / `preferredRefereeId`.** Request-status derivation drops `matched`/`declined`.
- **Riverpod v3 async rule:** in any `AsyncNotifier` async method, after every `await` write `if (!ref.mounted) return;` before touching `state`; register cancellation with `ref.onDispose(...)`. (Verified against the Riverpod v3 docs: `ref.mounted`, `ref.onDispose`.)
- **No `update` method name** on any `AsyncNotifier`-based notifier (project rule — `invalid_override`).
- **Referee shown as レフリー** in UI copy; internal identifiers stay English `referee`.
- **Spacing** uses `SizedBox` (not per-item `Padding`); use `AppSizes` constants, never hardcoded pixels.
- **Build verification:** each task runs `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`. A **single emulator pass** runs at the end (Task 12).
- **Codegen:** after editing any `@riverpod` / Freezed / json_serializable source, run `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`.

## File Structure

```
lib/features/task/
  domain/task.dart                    # MODIFY: drop feeAmount/feeCurrency; tasker -> PublicProfile?
  domain/task_creation_request.dart   # MODIFY: drop matchingStrategies
  domain/task_viewer_role.dart        # CREATE: pure role derivation
  data/public_profile_dto.dart        # CREATE (shared minimal profile)
  data/referee_request_dto.dart       # CREATE (camelCase)
  data/task_dto.dart                  # CREATE (camelCase)
  data/task_repository.dart           # REWRITE: ApiClient; no supabase_flutter
  ui/ (was presentation/)             # MOVE; *Controller -> *ViewModel
    task_detail_view_model.dart       # AsyncNotifier family owning task state (Task 7)
    task_role_provider.dart           # CREATE: thin composer of task+currentUser (Task 8)
    widgets/task_creation/referee_count_section.dart  # CREATE (replaces strategy widgets)
lib/features/matching/
  domain/referee_request.dart         # MODIFY: drop matchingStrategy/preferredRefereeId; referee -> PublicProfile?
  domain/public_profile.dart          # CREATE
  domain/matching_config.dart         # CREATE
  data/matching_config_dto.dart / *_slot_dto.dart / *_blocked_date_dto.dart  # CREATE
  data/matching_repository.dart       # REWRITE: config + assignments + cancel + availability
  matching_constants.dart             # DELETE deadline mirror
  ui/ (was presentation/)             # MOVE
lib/features/home/
  ui/home_view_model.dart             # Go-API providers
lib/core/async/progressive_poller.dart # CREATE
```

---

## Task 1: Domain cleanup + `PublicProfile` + `TaskViewerRole`

**Files:**
- Create: `lib/features/matching/domain/public_profile.dart` (+ generated)
- Modify: `lib/features/task/domain/task.dart` (drop `feeAmount`/`feeCurrency`; `tasker` → `PublicProfile?`; **revise `getDetailedStatuses` for the 4a data shape**)
- Modify: `lib/features/matching/domain/referee_request.dart` (drop `matchingStrategy`, `preferredRefereeId`; `referee` → `PublicProfile?`)
- Create: `lib/features/task/domain/task_viewer_role.dart`
- **Modify (type-change ripple — keep the tree compiling, review item 5):** `lib/features/home/presentation/widgets/task_card.dart` (`List<Profile>`→`List<PublicProfile>`, `_RefereeAvatarStack`/`_RefereeAvatarBubble` param types; reads `.avatarUrl`/`.username` unchanged), `lib/features/task/presentation/widgets/task_detail/tasker_referees_section.dart`, `lib/features/task/presentation/widgets/task_detail/task_detail_info_section.dart`. (These still live under `presentation/` at this point; T4/T5/T8 restructure them later.)
- Test: `test/features/task/domain/task_viewer_role_test.dart`, `test/features/task/domain/task_status_test.dart`

**Interfaces:**
- Produces:
  - `PublicProfile` (Freezed): `String userId`, `String username`, `String? avatarUrl`.
  - `TaskViewerRole { final bool isTasker; final RefereeRequest? myRequest; const TaskViewerRole({required this.isTasker, required this.myRequest}); bool get isAssignedReferee => myRequest != null; }`
  - `extension TaskRoleX on Task { TaskViewerRole viewerRole(String? internalUserId); }`
  - `Task.getDetailedStatuses(...)` revised so it does **not** infer state from a null `judgement`/`evidence` (always null in 4a), with a **pending-first** priority that matches the poll's `isDone` (poll continues while *any* request is `pending`): tasker → **any pending → `matching`**; else any accepted → `matching_complete`; else (all expired/cancelled) → `matching_failed`. So `[accepted, pending]` shows `matching`, not `matching_complete`. Referee → my-request pending → `matching` / accepted → `matching_complete` / expired-or-cancelled (inactive) / no my-request (none). 4b/4c judgement/evidence/payment branches stay for later but are unreachable with 4a data.
- Consumes: `Task`, `RefereeRequest` (domain only). `PublicProfile` has the `username`/`avatarUrl` the display widgets already read, so their bodies change only in type, not logic.

- [ ] **Step 1: Write the failing test** (constructor args match the REAL post-edit required fields — `RefereeRequest` requires `id`, `taskId`, `status`, `createdAt`; `matchingStrategy` is removed here)

```dart
// test/features/task/domain/task_viewer_role_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_viewer_role.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';

void main() {
  Task taskWith({required String taskerId, List<RefereeRequest> reqs = const []}) =>
      Task(id: 't1', taskerId: taskerId, title: 'x', status: 'open',
           createdAt: '2026-07-01T00:00:00Z', refereeRequests: reqs);
  RefereeRequest req({required String id, String? matchedRefereeId}) => RefereeRequest(
        id: id, taskId: 't1', status: 'accepted', createdAt: '2026-07-01T00:00:00Z',
        matchedRefereeId: matchedRefereeId,
      );

  test('null user -> neither', () {
    final r = taskWith(taskerId: 'u_owner').viewerRole(null);
    expect(r.isTasker, false);
    expect(r.isAssignedReferee, false);
  });
  test('tasker match', () {
    expect(taskWith(taskerId: 'u_me').viewerRole('u_me').isTasker, true);
  });
  test('assigned referee resolves myRequest', () {
    final t = taskWith(taskerId: 'u_owner', reqs: [
      req(id: 'r1', matchedRefereeId: 'u_other'),
      req(id: 'r2', matchedRefereeId: 'u_me'),
    ]);
    final r = t.viewerRole('u_me');
    expect(r.isTasker, false);
    expect(r.isAssignedReferee, true);
    expect(r.myRequest!.id, 'r2');
  });
  test('stranger -> neither', () {
    final r = taskWith(taskerId: 'u_owner', reqs: [req(id: 'r1', matchedRefereeId: 'u_other')])
        .viewerRole('u_stranger');
    expect(r.isTasker, false);
    expect(r.isAssignedReferee, false);
  });
}
```

Also write `test/features/task/domain/task_status_test.dart` for the 4a status derivation (judgement/evidence always null):

```dart
// test/features/task/domain/task_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';

void main() {
  Task t(String taskerId, List<RefereeRequest> reqs) => Task(
      id: 't1', taskerId: taskerId, title: 'x', status: 'open',
      createdAt: '2026-07-01T00:00:00Z', refereeRequests: reqs);
  RefereeRequest r(String status, {String? matched}) => RefereeRequest(
      id: 'r_$status', taskId: 't1', status: status,
      createdAt: '2026-07-01T00:00:00Z', matchedRefereeId: matched);

  group('tasker (4a, pending-first)', () {
    test('all pending -> matching', () =>
        expect(t('u_o', [r('pending')]).getDetailedStatuses('u_o'), ['matching']));
    test('accepted + pending -> matching (pending wins)', () =>
        expect(t('u_o', [r('accepted', matched: 'u_ref'), r('pending')])
            .getDetailedStatuses('u_o'), ['matching']));
    test('no pending + accepted -> matching_complete', () =>
        expect(t('u_o', [r('accepted', matched: 'u_ref')]).getDetailedStatuses('u_o'),
            contains('matching_complete')));
    test('accepted + expired (no pending) -> matching_complete', () =>
        expect(t('u_o', [r('accepted', matched: 'u_ref'), r('expired')])
            .getDetailedStatuses('u_o'), contains('matching_complete')));
    test('all expired -> matching_failed', () =>
        expect(t('u_o', [r('expired')]).getDetailedStatuses('u_o'), ['matching_failed']));
  });
  group('referee (4a)', () {
    test('my accepted -> matching_complete', () =>
        expect(t('u_o', [r('accepted', matched: 'u_me')]).getDetailedStatuses('u_me'),
            contains('matching_complete')));
    test('my pending -> matching', () =>
        expect(t('u_o', [r('pending', matched: null)]).getDetailedStatuses('u_me'),
            ['matching']));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/task/domain/`
Expected: FAIL (compile: `PublicProfile`/`viewerRole` undefined; `RefereeRequest` still requires `matchingStrategy`; status derivation still judgement-dependent).

- [ ] **Step 3: Implement**

Create `public_profile.dart` (Freezed: `userId`, `username`, `avatarUrl?`; no `fromJson` — DTO handles JSON). Edit `referee_request.dart`: remove `matchingStrategy` and `preferredRefereeId`; change `Profile? referee` → `PublicProfile? referee` (update imports; keep `Judgement? judgement`). Edit `task.dart`: remove `feeAmount`/`feeCurrency`; change `Profile? tasker` → `PublicProfile? tasker`. **Revise `getDetailedStatuses`** so it does not treat a null `judgement` as `matching`, using a **pending-first** priority (matches the poll's `isDone`): tasker → **any pending → `['matching']`**; else any accepted → `['matching_complete']`; else all expired/cancelled → `['matching_failed']`. So `[accepted, pending]` → `['matching']`. Referee → my-request pending → `['matching']` / accepted → `['matching_complete']`. Keep the 4b/4c judgement/evidence/payment branches (unreachable with 4a's null data). **Update the type-change consumers** so the tree still compiles: `task_card.dart` (`List<Profile>`→`List<PublicProfile>` in `_RefereeAvatarStack`/`_RefereeAvatarBubble`), `tasker_referees_section.dart`, `task_detail_info_section.dart` (bodies read `.username`/`.avatarUrl`, unchanged). Create `task_viewer_role.dart`:

```dart
// lib/features/task/domain/task_viewer_role.dart
import '../../matching/domain/referee_request.dart';
import 'task.dart';

class TaskViewerRole {
  final bool isTasker;
  final RefereeRequest? myRequest;
  const TaskViewerRole({required this.isTasker, required this.myRequest});
  bool get isAssignedReferee => myRequest != null;
}

extension TaskRoleX on Task {
  TaskViewerRole viewerRole(String? internalUserId) {
    if (internalUserId == null) return const TaskViewerRole(isTasker: false, myRequest: null);
    RefereeRequest? mine;
    for (final r in refereeRequests) {
      if (r.matchedRefereeId == internalUserId) { mine = r; break; }
    }
    return TaskViewerRole(isTasker: taskerId == internalUserId, myRequest: mine);
  }
}
```

Run build_runner; fix references broken by the field removals (`grep -rn "feeAmount\|feeCurrency\|matchingStrategy\|preferredRefereeId"` in `lib/features/task` `lib/features/matching` `lib/features/home`).

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/task/domain/ && flutter analyze`
Expected: PASS; `flutter analyze` clean (the type-change consumers — `task_card.dart`, `tasker_referees_section.dart`, `task_detail_info_section.dart` — compile against `PublicProfile`).

- [ ] **Step 5: Build check + commit**

Run: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

```bash
cd peppercheck_flutter && git add lib/features/task lib/features/matching/domain lib/features/home/presentation/widgets test/features/task/domain
git commit -m "feat(flutter): PublicProfile + TaskViewerRole; 4a status derivation; drop fee/strategy fields"
```

---

## Task 2: Task DTOs (camelCase) + repository over `ApiClient`

**Files:**
- Create: `lib/core/network/paginated_fetch.dart` (shared cursor-paging helper; URI-encodes the opaque cursor)
- Create: `lib/features/task/data/public_profile_dto.dart`, `referee_request_dto.dart`, `task_dto.dart` (+ generated)
- Rewrite: `lib/features/task/data/task_repository.dart` (remove `supabase_flutter`)
- Modify: `lib/features/task/domain/task_creation_request.dart` (drop `matchingStrategies`)
- Test: `test/core/network/paginated_fetch_test.dart`, `test/features/task/data/task_repository_test.dart`

**Interfaces:**
- Produces on `TaskRepository`:
  - `Future<Task> createDraft(TaskCreationRequest req)` → `POST /api/v1/tasks`
  - `Future<Task> updateDraft(String id, TaskCreationRequest req)` → `PATCH /api/v1/tasks/{id}`
  - `Future<void> deleteDraft(String id)` → `DELETE /api/v1/tasks/{id}`
  - `Future<Task> publish(String id, {required int refereeCount})` → `POST /api/v1/tasks/{id}/publish`
  - `Future<Task> getTask(String id)` → `GET /api/v1/tasks/{id}`
  - `Future<List<Task>> fetchMyTasks()` → `GET /api/v1/me/tasks`, **following `nextCursor` until exhausted** and returning the full list (review item 1)
- Consumes: `ApiClient`. DTO shape per **§7.1**. Template: `features/auth/data/me_repository.dart` + `me_dto.dart`.

**Pagination decision (review item 1):** `/me/tasks` (and `/me/assignments`, Task 3) are the caller's **active** lists — bounded, small sets — so the repository **aggregates all pages** (loops `?cursor=nextCursor` until `nextCursor == null`) and returns a plain `List<Task>`; the home UI is unchanged (no "load more"). A cursor-paged type + "load more" UI is deferred until a genuinely large list (e.g. a future history view) needs it.

- [ ] **Step 1: Write the failing repository test**

`task_repository_test.dart` (fake `ApiClient`, per `me_repository_test.dart`). Assert against §7.1 camelCase:
- `createDraft` → `postJson('/api/v1/tasks', body: {'title','description','criteria','dueDate'})`, maps `Task` (empty `refereeRequests`).
- `updateDraft` → `patchJson('/api/v1/tasks/t1', body: {...})`.
- `deleteDraft` → `deleteJson('/api/v1/tasks/t1')`.
- `publish` → `postJson('/api/v1/tasks/t1/publish', body: {'refereeCount': 2})`; mapped `Task.status == 'open'` with two `pending` requests.
- `getTask` maps a full §7.1 task incl. `tasker.username` → `PublicProfile` and a matched request's `referee.avatarUrl`.
- `fetchMyTasks` **paging + opaque cursor**: page 1 returns `{'tasks':[a], 'nextCursor':'a+b/c=='}` (a cursor containing `+` and `/`), page 2 returns `{'tasks':[b], 'nextCursor':null}` → the result is `[a, b]`, exactly two `getJson` calls, and the second path is `/api/v1/me/tasks?cursor=a%2Bb%2Fc%3D%3D` (the cursor is **URI-encoded** as an opaque value, `Uri.encodeQueryComponent`).
- `publish` propagates `ApiException(code:'validation_error')`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/task/data/task_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement DTOs + repository**

Create `public_profile_dto.dart` (`userId,username,avatarUrl`) → `PublicProfile`; `referee_request_dto.dart` (§7.1 request fields, camelCase, nested `referee` PublicProfileDto) → `RefereeRequest`; `task_dto.dart` (§7.1 task, nested `tasker` + `refereeRequests`) → `Task`. Add a small **shared cursor-paging helper in `core/network`** — `Future<List<Map<String,dynamic>>> fetchAllPages(ApiClient c, String path, {required String itemsKey})` — that repeatedly calls `getJson`, appends `response[itemsKey]`, and re-requests with `?cursor=${Uri.encodeQueryComponent(nextCursor)}` (the cursor is **opaque** — always URI-encode; never string-concat raw) until `nextCursor == null`. Both `TaskRepository.fetchMyTasks` (this task) and `MatchingRepository.fetchMyAssignments` (Task 3) use it, so the encoding is centralized. Rewrite `task_repository.dart` on `ApiClient`; publish sends `{refereeCount}` (no `referee_requests:[{matching_strategy}]`); `fetchMyTasks` = `fetchAllPages(..., itemsKey:'tasks')` mapped through `TaskDto`. Remove `Supabase.instance.client` and all `_client.auth.currentUser?.id`. Drop `matchingStrategies` from `task_creation_request.dart`. Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/task/data/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/core/network/paginated_fetch.dart lib/features/task/data lib/features/task/domain/task_creation_request.dart test/core/network test/features/task/data
git commit -m "feat(flutter): task DTOs (camelCase, PublicProfile) + repository over ApiClient"
```

---

## Task 3: Matching repository foundation — config, assignments, cancel

**Files:**
- Create: `lib/features/matching/domain/matching_config.dart`, `lib/features/matching/data/matching_config_dto.dart` (+ generated)
- Rewrite (part 1): `lib/features/matching/data/matching_repository.dart` (config + assignments + cancel; availability follows in Task 9; remove `supabase_flutter` for these methods)
- Create: `matchingConfigProvider` (keepAlive)
- Test: `test/features/matching/data/matching_repository_core_test.dart`

**Interfaces:**
- Produces:
  - `MatchingConfig { int openDeadlineHours; int cancelDeadlineHours; int rematchCutoffHours; int maxRefereesPerTask; int matchingPointCost; }`
  - `MatchingRepository.fetchConfig()` → `GET /api/v1/matching/config`
  - `MatchingRepository.fetchMyAssignments()` → `GET /api/v1/me/assignments`, **following `nextCursor`** (review item 1) → `List<Task>` (real requests + embedded `tasker`)
  - `MatchingRepository.cancelAssignment(String requestId)` → `POST /api/v1/referee-requests/{id}/cancel`
  - `matchingConfigProvider` → `MatchingConfig`
- Consumes: `ApiClient`, `TaskDto` (Task 2, for assignments). §7.1.

**Transitional repository state (review item 4):** this task makes `MatchingRepository` depend on **both** `ApiClient` (config / assignments / cancel) **and** the Supabase client (still used by the availability methods until Task 9). This is a deliberate intermediate state — the CI `supabase_flutter` import ban for `features/matching` is only added in Task 12, so the interim commit is legal. **Task 9 removes the Supabase dependency entirely** once availability is on `ApiClient`.

- [ ] **Step 1: Write the failing test**

`matching_repository_core_test.dart` (fake `ApiClient`): `fetchConfig` maps `{openDeadlineHours:24,cancelDeadlineHours:12,rematchCutoffHours:14,maxRefereesPerTask:2,matchingPointCost:1}` → `MatchingConfig` (`cancelDeadlineHours==12`, `maxRefereesPerTask==2`); `fetchMyAssignments` maps `{"assignments":[<task>], "nextCursor":null}` → `List<Task>` with a real request id (assert none is `'synthetic-id'`), and **pages** when `nextCursor` is non-null (two `getJson` calls, aggregated result); `cancelAssignment('r1')` → `postJson('/api/v1/referee-requests/r1/cancel')`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/matching/data/matching_repository_core_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `MatchingConfig` + `matching_config_dto.dart`; add `matchingConfigProvider`. Add `fetchConfig`, `fetchMyAssignments` (uses the shared `fetchAllPages(..., itemsKey:'assignments')` from Task 2 — same opaque-cursor URI-encoding — mapped through `TaskDto`), `cancelAssignment` to `MatchingRepository` on `ApiClient`; inject `ApiClient` **alongside** the existing Supabase client (availability stays on Supabase until Task 9); remove the old `cancel_referee_assignment` RPC. Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/matching/data/matching_repository_core_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/features/matching/domain lib/features/matching/data test/features/matching/data
git commit -m "feat(flutter): matching config + assignments + cancel over ApiClient"
```

---

## Task 4: `home` lists over the Go API

**Files:**
- Move/modify: `lib/features/home/presentation/home_controller.dart` → `lib/features/home/ui/home_view_model.dart`
- Modify: `lib/features/home/ui/home_screen.dart` (moved imports)
- Test: `test/features/home/ui/home_view_model_test.dart`

**Interfaces:**
- Produces: `activeUserTasksProvider` → `TaskRepository.fetchMyTasks()` (Task 2); `activeRefereeTasksProvider` → `MatchingRepository.fetchMyAssignments()` (Task 3). Pull-to-refresh / `onResume` invalidation preserved.
- Consumes: `TaskRepository` (Task 2), `MatchingRepository` (Task 3).

- [ ] **Step 1: Write the failing test**

`home_view_model_test.dart` (fake repos): `activeUserTasksProvider` resolves to `fetchMyTasks()`; `activeRefereeTasksProvider` resolves to `fetchMyAssignments()` whose tasks have real request ids (assert no `id == 'synthetic-id'`).

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/home/ui/home_view_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`git mv` `home/presentation/home_controller.dart` → `home/ui/home_view_model.dart`; rename the class. Point `activeUserTasksProvider` at `TaskRepository.fetchMyTasks()` and `activeRefereeTasksProvider` at `MatchingRepository.fetchMyAssignments()`. Remove Supabase; delete the `'synthetic-id'` path (now server-provided). Update `home_screen.dart` imports. Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/home/`
Expected: PASS.

- [ ] **Step 5: Build + commit**

Run: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

```bash
cd peppercheck_flutter && git add lib/features/home test/features/home
git commit -m "feat(flutter): home task + assignment lists over the Go API (no synthetic request)"
```

---

## Task 5: `task` Option E restructure + config-bounded referee-count publish UI

**Files:**
- Move: `lib/features/task/presentation/` → `lib/features/task/ui/`; `*_controller.dart` → `*_view_model.dart`, `*Controller` → `*ViewModel`
- Create: `lib/features/task/ui/widgets/task_creation/referee_count_section.dart`
- Delete: `matching_strategy_selection_section.dart`, `strategy_button.dart`
- Modify: `task_creation_view_model.dart`, `task_creation_state.dart`, router/consumers
- Test: `test/features/task/ui/*`

**Interfaces:**
- Produces: `TaskCreationViewModel` with `saveDraft()` and `publish({required int refereeCount})` (never `update`). `RefereeCountSection({required int selected, required int maxCount, required ValueChanged<int> onChanged, required bool loading})`.
- Consumes: `TaskRepository` (Task 2), `matchingConfigProvider` (Task 3).

- [ ] **Step 1: Move files and rename classes**

`git mv` `presentation/*` → `ui/*` (`_view_model` suffix); rename notifier classes + `part`/generated refs; move `presentation/widgets` → `ui/widgets`. Update imports (`grep -rn "features/task/presentation"`).

- [ ] **Step 2: Referee-count selector wired to config (review item 3)**

Create `referee_count_section.dart`: a 1..`maxCount` segmented selector, **no** point/pt text. `maxCount = ref.watch(matchingConfigProvider).maxRefereesPerTask` (default read); while the config is **loading**, pass `loading:true` → the selector is disabled and `selected` is pinned to 1; if `selected > maxCount` after load, **clamp** to `maxCount`. Delete `matching_strategy_selection_section.dart` + `strategy_button.dart` and the `matchingStrategyCostProvider` (billing cost) usage.

- [ ] **Step 3: Publish action**

In `task_creation_view_model.dart`, split into `saveDraft()` (create/patch, status draft) and `publish({refereeCount})` (`repo.publish(id, refereeCount: refereeCount)`); publish requires a saved draft id. Surface `ApiException(code:'validation_error')` as the existing error dialog. `task_creation_state.dart` holds `refereeCount` (default 1); drop `matchingStrategies`.

- [ ] **Step 4: Tests**

Move `test/features/task/presentation/*` → `test/features/task/ui/*`, rename classes. Add: `RefereeCountSection` renders 1..maxCount, no `pt`, disabled while `loading`, and clamps a stale `selected`; `TaskCreationViewModel.publish` calls `repo.publish` with the selected count; a `validation_error` surfaces the dialog.

- [ ] **Step 5: Run + build + commit**

Run: `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test test/features/task/`
Run: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`
Expected: PASS; no `features/task/presentation` imports remain.

```bash
cd peppercheck_flutter && git add lib/features/task test/features/task lib/app
git commit -m "refactor(flutter): task to Option E ui/; config-bounded referee-count publish (no point cost)"
```

---

## Task 6: `core` progressive poller

> Reordered ahead of the task-detail role work: `taskRoleProvider` (Task 8) composes `taskDetailProvider` (Task 7), which uses this poller — so poller → taskDetail → role provider + migration.

**Files:**
- Create: `lib/core/async/progressive_poller.dart`
- Test: `test/core/async/progressive_poller_test.dart`

**Interfaces:**
- Produces: `kDefaultProgressiveSchedule` (`[1,1,2,2,3]s`); `class CancellationToken { void cancel(); bool get isCancelled; }`; `Future<T> pollUntil<T>({ required Future<T> Function() fetch, required bool Function(T) isDone, List<Duration> schedule, CancellationToken? cancel, Future<void> Function(Duration) sleep })` — fetch immediately, return on `isDone`, else wait `schedule[i]` then re-fetch; stop after the schedule (return last value) or on cancel. `sleep` injectable.
- Consumes: nothing (provider-neutral).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/async/progressive_poller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/core/async/progressive_poller.dart';

void main() {
  test('returns as soon as isDone', () async {
    var calls = 0;
    final r = await pollUntil<int>(
      fetch: () async { calls++; return calls; }, isDone: (v) => v >= 3,
      schedule: const [Duration.zero, Duration.zero, Duration.zero], sleep: (_) async {});
    expect(r, 3); expect(calls, 3);
  });
  test('stops after schedule exhausted, returns last', () async {
    var calls = 0;
    final r = await pollUntil<int>(
      fetch: () async { calls++; return calls; }, isDone: (v) => false,
      schedule: const [Duration.zero, Duration.zero], sleep: (_) async {}); // 3 attempts
    expect(calls, 3); expect(r, 3);
  });
  test('cancellation stops further polling', () async {
    final token = CancellationToken(); var calls = 0;
    final r = await pollUntil<int>(
      fetch: () async { calls++; if (calls == 2) token.cancel(); return calls; },
      isDone: (v) => false, schedule: const [Duration.zero, Duration.zero, Duration.zero],
      cancel: token, sleep: (_) async {});
    expect(calls, 2); expect(r, 2);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/core/async/progressive_poller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/core/async/progressive_poller.dart
import 'dart:async';

const kDefaultProgressiveSchedule = <Duration>[
  Duration(seconds: 1), Duration(seconds: 1),
  Duration(seconds: 2), Duration(seconds: 2), Duration(seconds: 3),
];

class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

Future<T> pollUntil<T>({
  required Future<T> Function() fetch,
  required bool Function(T) isDone,
  List<Duration> schedule = kDefaultProgressiveSchedule,
  CancellationToken? cancel,
  Future<void> Function(Duration) sleep = _defaultSleep,
}) async {
  T value = await fetch();
  if (isDone(value) || (cancel?.isCancelled ?? false)) return value;
  for (final delay in schedule) {
    if (cancel?.isCancelled ?? false) return value;
    await sleep(delay);
    if (cancel?.isCancelled ?? false) return value;
    value = await fetch();
    if (isDone(value)) return value;
  }
  return value;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/core/async/progressive_poller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd peppercheck_flutter && git add lib/core/async test/core/async
git commit -m "feat(flutter): shared progressive poller in core (pollUntil)"
```

---

## Task 7: `taskDetail` AsyncNotifier family + matching-result polling

**Files:**
- Create: `lib/features/task/ui/task_detail_view_model.dart` (+ generated) — codegen `AsyncNotifier` family owning the task state
- Modify: `lib/features/task/ui/task_detail_screen.dart` (read `taskDetailProvider(taskId)` instead of the read-only `taskProvider`)
- Modify: post-publish navigation to start the poll
- Test: `test/features/task/ui/task_detail_view_model_test.dart`

**Interfaces:**
- Produces: `@riverpod class TaskDetail extends _$TaskDetail { Future<Task> build(String taskId); Future<void> pollUntilMatched(); }` — `build` fetches `repo.getTask(taskId)`; `pollUntilMatched` runs `pollUntil` until no request is `pending`, updating `state` each fetch. **Riverpod v3:** guard each post-`await` write with `if (!ref.mounted) return;`; register `ref.onDispose(_token.cancel)`. `taskDetailProvider(taskId)` is consumed by `taskRoleProvider` (Task 8).
- Consumes: `pollUntil`/`CancellationToken` (Task 6), `TaskRepository.getTask` (Task 2).

**Backend behavior note:** polling runs on the **detail screen only** (home uses invalidate + FCM nudge). The read-only `taskProvider` is replaced here because a `FutureProvider` cannot hold poll-updated state.

- [ ] **Step 1: Write the failing test**

`task_detail_view_model_test.dart` (fake `TaskRepository` returning a `pending` task then an `accepted` task; a no-op `sleep` seam on `pollUntilMatched`): `build` exposes the first task; `pollUntilMatched` calls `getTask` until all requests are non-`pending`, then stops (assert no further `getTask` after accepted). Assert that after `container.dispose()` the token is cancelled and no state write occurs (use a `ProviderContainer` and dispose mid-poll; assert no `UnmountedRefException`).

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/task/ui/task_detail_view_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/features/task/ui/task_detail_view_model.dart (sketch; codegen part omitted)
@riverpod
class TaskDetail extends _$TaskDetail {
  final _token = CancellationToken();
  late final String _taskId; // stashed from build() so methods can reach it

  @override
  Future<Task> build(String taskId) async {
    _taskId = taskId;                 // build()'s arg is not auto-visible to methods
    ref.onDispose(_token.cancel);
    return ref.read(taskRepositoryProvider).getTask(taskId);
  }

  Future<void> pollUntilMatched() async {
    final repo = ref.read(taskRepositoryProvider);
    await pollUntil<Task>(
      fetch: () async {
        final t = await repo.getTask(_taskId);
        if (ref.mounted) state = AsyncData(t); // Riverpod v3 guard
        return t;
      },
      isDone: (t) => t.refereeRequests.every((r) => r.status != 'pending'),
      cancel: _token,
    );
  }
}
```

> **Review item 3:** `build(String taskId)`'s parameter is **not** in scope inside other notifier methods, so stash it in a `late final String _taskId` in `build` (as above) and reference `_taskId` in `pollUntilMatched`. (Do not reference the bare `taskId` in the method — it would not compile.)

Point `task_detail_screen.dart` at `taskDetailProvider(taskId)`. Trigger `ref.read(taskDetailProvider(taskId).notifier).pollUntilMatched()` after a successful publish (on nav/first build of a still-`pending` task). Make `sleep` injectable for the test (e.g. an overridable provider or a named param passed through). Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/task/ui/task_detail_view_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Build + commit**

Run: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

```bash
cd peppercheck_flutter && git add lib/features/task/ui test/features/task/ui
git commit -m "feat(flutter): taskDetail AsyncNotifier polls pending->accepted (Riverpod v3 mounted/onDispose)"
```

---

## Task 8: `taskRoleProvider` + task-detail role migration; downstream NOT mounted

**Files:**
- Create: `lib/features/task/ui/task_role_provider.dart` (+ generated) — thin composer `taskRole(ref, taskId)`
- Modify: `lib/features/task/ui/task_detail_screen.dart` (mount sections off `taskRoleProvider`; DO NOT mount evidence/judgement/evidence-timeout/report)
- Modify: `lib/features/task/ui/widgets/task_detail/withdraw_matching_button.dart` (watch `taskRoleProvider(task.id)` for `myRequest`; remove Supabase — cutoff wiring in Task 10)
- Modify: `lib/features/task/ui/widgets/task_detail/task_detail_info_section.dart` (watch the role provider or receive `isTasker`; remove Supabase)
- Test: `test/features/task/ui/task_role_provider_test.dart`, `test/features/task/ui/task_detail_role_test.dart`

**Interfaces:**
- Produces: `@riverpod Future<TaskViewerRole> taskRole(Ref ref, String taskId)` — composes `taskDetailProvider(taskId)` (Task 7) + `currentAppUserProvider`, delegating to the pure `Task.viewerRole` (Task 1). No logic in the provider.
- Consumes: `taskDetailProvider` (Task 7), `currentAppUserProvider` (`AsyncValue<AppUser?>`), `Task.viewerRole` (Task 1).

**Completion criterion (review item 5):** `grep -rn "package:supabase_flutter" lib/features/task/ui` is **empty**; opening a matched task issues no Supabase call. Downstream sections are re-mounted in 4b/4c.

- [ ] **Step 1: Write the failing tests**

`task_role_provider_test.dart` (override `taskDetailProvider` + `currentAppUserProvider`): resolves `isTasker` when the current `AppUser.internalUserId == task.taskerId`; resolves `myRequest` when the user is a matched referee; `AppUser?==null` → `isTasker:false, myRequest:null`. `task_detail_role_test.dart` (widget, overriding `taskRoleProvider`): `isTasker` → `TaskerRefereesSection` shown, `WithdrawMatchingButton` absent; matched referee → `WithdrawMatchingButton` present (its own `ref.watch(taskRoleProvider(task.id))` yields a non-null `myRequest`); assert **no** `JudgementSection`/`EvidenceSubmissionSection`/report menu in the tree.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/task/ui/task_role_provider_test.dart test/features/task/ui/task_detail_role_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/features/task/ui/task_role_provider.dart
@riverpod
Future<TaskViewerRole> taskRole(Ref ref, String taskId) async {
  final task = await ref.watch(taskDetailProvider(taskId).future);
  final me = await ref.watch(currentAppUserProvider.future);
  return task.viewerRole(me?.internalUserId); // delegate to the pure fn (Task 1)
}
```

In `task_detail_screen.dart`: read `ref.watch(taskRoleProvider(taskId))` and mount `TaskerRefereesSection` only under `role.isTasker`. `WithdrawMatchingButton` and `task_detail_info_section` become `Consumer`s reading `taskRoleProvider(task.id)` (no threaded params); delete their `Supabase`/`_myRequest()` code. **Comment out the mounts** of `EvidenceSubmissionSection`, `EvidenceTimeoutRefereeSection`, `JudgementSection`, and `report_menu_button` with `// Phase 4b`/`4c` markers (remove the old `_shouldShowEvidence*` helpers + imports so no `supabase_flutter` import remains). Run build_runner.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/task/ui/`
Run: `cd peppercheck_flutter && grep -rn "package:supabase_flutter" lib/features/task/ui` (expect empty)
Expected: PASS; grep empty.

- [ ] **Step 5: Build + commit**

Run: `cd peppercheck_flutter && flutter analyze && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

```bash
cd peppercheck_flutter && git add lib/features/task/ui test/features/task/ui
git commit -m "feat(flutter): taskRoleProvider + task-detail role via AppUser; do not mount 4b/4c/report"
```

---

## Task 9: `matching` availability repository + Option E restructure

**Files:**
- Rewrite (part 2): `lib/features/matching/data/matching_repository.dart` (time-slots + blocked-dates over `ApiClient`; remove remaining `supabase_flutter`)
- Create: `lib/features/matching/data/referee_time_slot_dto.dart`, `referee_blocked_date_dto.dart` (+ generated)
- Move: `lib/features/matching/presentation/` → `lib/features/matching/ui/`; controllers → `*_view_model.dart`
- Test: `test/features/matching/data/matching_availability_repository_test.dart`

**Interfaces:**
- Produces on `MatchingRepository` (§7.1): `fetchTimeSlots()`/`createTimeSlot(...)`/`updateTimeSlot(...)`/`deleteTimeSlot(id)` → `.../me/availability/time-slots`; `fetchBlockedDates()`/`createBlockedDate(...)`/`updateBlockedDate(...)`/`deleteBlockedDate(id)` → `.../me/availability/blocked-dates`.
- Consumes: `ApiClient`, the DTOs.

- [ ] **Step 1: Write the failing test**

`matching_availability_repository_test.dart` (fake `ApiClient`): `fetchTimeSlots` maps `{"timeSlots":[...]}` → `List<RefereeAvailableTimeSlot>`; `createTimeSlot` posts `{dow,startMin,endMin,isActive}` and returns the created slot; `deleteTimeSlot` → `deleteJson('.../time-slots/{id}')`; same for blocked-dates (`{startDate,endDate,reason?}`).

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/matching/data/matching_availability_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement + restructure**

Write the DTOs + the eight methods on `ApiClient`; **remove the Supabase client dependency from `MatchingRepository` entirely** (it was retained transitionally in Task 3 for availability only — with these methods migrated, no matching method uses Supabase, so drop the injected Supabase client and the `supabase_flutter` import; review item 4). `git mv` `matching/presentation` → `matching/ui`; controllers → `*_view_model.dart` (no `update` method name). Update imports (`grep -rn "features/matching/presentation"`), incl. the Profile screen mounting the availability sections. Run build_runner.

- [ ] **Step 3b: Confirm no residual Supabase in matching**

Run: `cd peppercheck_flutter && grep -rn "package:supabase_flutter" lib/features/matching` (expect empty).

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/matching/`
Expected: PASS.

- [ ] **Step 5: Build + commit**

Run: `cd peppercheck_flutter && flutter analyze && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

```bash
cd peppercheck_flutter && git add lib/features/matching lib/features/profile test/features/matching
git commit -m "feat(flutter): referee availability over the Go API; matching to Option E ui/"
```

---

## Task 10: Config-driven withdraw button

**Files:**
- Modify: `lib/features/task/ui/widgets/task_detail/withdraw_matching_button.dart` (cutoff from `matchingConfigProvider`; `myRequest` via `taskRoleProvider(task.id)` from Task 8; cancel via `MatchingRepository.cancelAssignment` from Task 3)
- Delete: `lib/features/matching/matching_constants.dart` (`kRefereeCancelDeadlineHours`) if nothing else remains
- Test: `test/features/task/ui/withdraw_button_test.dart`

**Interfaces:**
- Consumes: `matchingConfigProvider` (Task 3), `taskRoleProvider` → `myRequest` (Task 8), `MatchingRepository.cancelAssignment` (Task 3).

- [ ] **Step 1: Write the failing test**

`withdraw_button_test.dart` (fake `matchingConfigProvider` `cancelDeadlineHours:12`; `myRequest` `status:'accepted'`): the button shows when `dueDate` is > 12h ahead and hides when within 12h, when `myRequest` is null, or when the judgement is terminal (`approved`/`review_timeout`/`evidence_timeout`/`confirmed`); tapping calls `cancelAssignment(myRequest.id)` and invalidates `taskDetailProvider`/`activeUserTasksProvider`/`activeRefereeTasksProvider`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd peppercheck_flutter && flutter test test/features/task/ui/withdraw_button_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Rewrite `WithdrawMatchingButton` to obtain `myRequest` from `ref.watch(taskRoleProvider(task.id))` (set in Task 8) and read the cutoff from `ref.watch(matchingConfigProvider)` (not `kRefereeCancelDeadlineHours`); keep the terminal-judgement guard set; on tap call `cancelAssignment(myRequest!.id)` then invalidate `taskDetailProvider`/`activeUserTasksProvider`/`activeRefereeTasksProvider`. Delete `matching_constants.dart` deadline mirror + its remaining consumers.

- [ ] **Step 4: Run to verify it passes**

Run: `cd peppercheck_flutter && flutter test test/features/task/ui/withdraw_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Build + commit**

Run: `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

```bash
cd peppercheck_flutter && git add lib/features/task/ui lib/features/matching test/features/task/ui
git commit -m "feat(flutter): config-driven referee withdraw cutoff + cancel over the Go API"
```

---

## Task 11: Matching notification loc-keys verification

**Files:**
- Test: `test/features/notification/matching_loc_keys_test.dart`
- Modify (only on a mismatch): `lib/features/notification/application/notification_text_resolver.dart`

- [ ] **Step 1: Write the verification test**

For each key (`notification_request_matched_tasker`, `notification_task_assigned_referee`, `notification_matching_reassigned_tasker`, `notification_matching_cancelled_pending_tasker`, `notification_matching_expired_refunded_tasker`), assert `resolveNotificationText(titleLocKey: key+'_title', bodyLocKey: key+'_body', locArgs: ['My Task','2026-08-01T00:00:00Z'])` returns non-empty title+body and the body contains `locArgs[0]` (task title) — the ordering contract with backend §8 (`[0]`=taskTitle, `[1]`=deadline).

- [ ] **Step 2: Run**

Run: `cd peppercheck_flutter && flutter test test/features/notification/matching_loc_keys_test.dart`
Expected: PASS (verify-only). If FAIL, fix the resolver arg ordering only.

- [ ] **Step 3: Commit**

```bash
cd peppercheck_flutter && git add test/features/notification lib/features/notification/application
git commit -m "test(flutter): verify matching notification loc-keys and arg ordering"
```

---

## Task 12: CI import checks + full verification + single emulator pass

**Files:**
- Modify: the architecture-import CI check (forbid `supabase_flutter` in `features/task`, `features/matching`, `features/home`)

- [ ] **Step 1: Extend the import check**

Add `features/task`, `features/matching`, `features/home` to the CI rule. Run locally: `grep -rn "package:supabase_flutter" lib/features/task lib/features/matching lib/features/home` must be empty.

- [ ] **Step 2: Full analyze + tests + build**

Run:
- `cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs`
- `cd peppercheck_flutter && dart format --set-exit-if-changed lib test`
- `cd peppercheck_flutter && flutter analyze`
- `cd peppercheck_flutter && flutter test`
- `cd peppercheck_flutter && flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`

Expected: all PASS.

- [ ] **Step 3: Single emulator verification pass**

With the Go API + worker running and a dev sign-in, verify: create/edit/delete a draft; publish (refereeCount 1 and 2; confirm the selector caps at the config max) → task shows マッチング中 → progressive polling flips it to accepted (レフリーが見つかりました) without manual refresh; open a matched task as tasker (referee cards show username/avatar) and as referee (withdraw visible before cutoff); cancel → re-match; edit availability (slot + blocked date); confirm evidence/judgement/report are absent and no Supabase error appears. Record the result.

- [ ] **Step 4: Commit**

```bash
cd peppercheck_flutter && git add .github
git commit -m "ci(flutter): forbid supabase_flutter in task/matching/home features"
```

---

## Self-Review

**Spec coverage (§ → task):** wire contract §7.1/P4aF-D7 → frozen in backend spec + consumed by T2/T3/T9; task authoring/publish §2.1 → T2/T5; config-bounded referee count, no cost §2.1/P4aF-D1/review#3 → T5 (config from T3); `PublicProfile` embedding P4aF-D7/review#2 → T1/T2; `TaskViewerRole` pure fn §2.5 → T1; `taskRoleProvider` (thin composer) §2.5 → T8; home lists + real assignment rows §2.3/review#4 → T3(assignments)+T4; assignments owned by `MatchingRepository` review#4 → T3; shared poller §2.7/P4aF-D6 → T6; async-match polling owner (AsyncNotifier, Riverpod v3 mounted/onDispose) §2.7/§3/review#6 → T7; task-detail role→AppUser via provider + downstream not-mounted + zero-supabase criterion §2.4/§2.5/P4aF-D3/review#5 → T8; matching config §2.2 → T3; availability CRUD + Option E §2.2/P4aF-D5 → T9; cancel + config cutoff §2.2 → T3+T10; notification loc-keys §2.6 → T11; CI import + emulator §7 → T12. Out-of-scope (evidence/judgement/reports/point cost/IAP retrofit/is_accepting editing) correctly untasked.

**Placeholder scan:** pure-logic tasks (T1, T7) carry full compilable code (T1's `RefereeRequest` constructor uses the real required fields — `id`,`taskId`,`status`,`createdAt` — after `matchingStrategy` removal); repository/UI tasks cite the concrete template (`me_repository`) and pin endpoints/bodies to §7.1. No "add error handling"/"similar to Task N"/TBD.

**Type consistency:** `ApiClient.{getJson,postJson,patchJson,putJson,deleteJson}` consumed by `TaskRepository` (T2) + `MatchingRepository` (T3/T9). `PublicProfile`/`PublicProfileDto` (T1/T2) nested in `Task.tasker`/`RefereeRequest.referee`. `TaskViewerRole`/`Task.viewerRole` (T1) → `taskRoleProvider` (T8) → task detail + `WithdrawMatchingButton` (T8/T10). `pollUntil`/`CancellationToken` (T6) → `TaskDetail.pollUntilMatched` (T7); `taskDetailProvider` (T7) → `taskRoleProvider` (T8). `matchingConfigProvider`/`MatchingConfig.{maxRefereesPerTask,cancelDeadlineHours}` (T3) → referee-count selector (T5) + withdraw button (T10). `MatchingRepository.{fetchConfig,fetchMyAssignments,cancelAssignment}` (T3) → home (T4), withdraw (T10). `TaskRepository.{createDraft,updateDraft,deleteDraft,publish,getTask,fetchMyTasks}` (T2) → T4/T5/T7. Consistent.

**Review items resolved:** #1 (contract granularity) → §7.1 pinned, referenced in Global Constraints + T2/T3/T9; #2 (profile DTO) → `PublicProfile(Dto)` + embedding, T1/T2; #3 (count↔config) → T5 wires `matchingConfigProvider`, clamp + loading + test; #4 (assignment ownership/order) → `MatchingRepository.fetchMyAssignments` built in T3 before home T4; #5 (Supabase in downstream) → T8 not-mounts + zero-`supabase_flutter` grep criterion; #6 (poll owner/dispose) → T7 `AsyncNotifier` family + Riverpod v3 `ref.mounted`/`ref.onDispose`, detail-only. **Role provider (operator-requested):** pure `Task.viewerRole` (T1) + thin `taskRoleProvider` (T8) composing `taskDetailProvider` + `currentAppUserProvider` — no prop-drilling, logic stays container-testable. Minors: T1 test now compiles + drops `RefereeRequest.matchingStrategy`; file-move steps are mechanical (T5/T9) with behavior tests written for the new referee-count/availability surface.

**Review items resolved (round 2):** R2#1 (pagination) → `fetchMyTasks` (T2) / `fetchMyAssignments` (T3) follow `nextCursor` to aggregate all pages of the bounded active lists, with a two-page test; "load more" UI deferred; R2#2 (status derivation) → T1 revises `getDetailedStatuses` for the 4a null-judgement shape (any-accepted → matched, not "matching") with `task_status_test.dart`; R2#3 (T7 `taskId` scope) → build stashes `late final _taskId`, `pollUntilMatched` uses `_taskId` (bare `taskId` would not compile); R2#4 (T3→T9 repo state) → T3 injects `ApiClient` alongside Supabase (availability transitional), T9 removes Supabase fully with a grep gate; the matching import ban lands in T12 so interim commits are legal; R2#5 (`PublicProfile` ripple) → T1 updates `task_card.dart` + `tasker_referees_section` + `task_detail_info_section` in the same commit to keep the tree compiling. R2 minor: design body unified to non-mount / detail-only poll / config-bounded count (stale "render empty"/"1–2 fixed"/"home poll" phrasing removed).

**Review items resolved (round 3):** R3#1 (multi-referee status priority) → T1 `getDetailedStatuses` is **pending-first** (any pending → `matching`; else accepted → `matching_complete`; else `matching_failed`), so `[accepted, pending]` shows `matching` — consistent with the poll's `isDone` (`every != pending`); `task_status_test.dart` adds the `[accepted, pending] → matching` case; R3#2 (§5 stale "home + progressive poll") → File Structure now shows the poll on `task_detail_view_model` (detail-only), home has no poll; R3#3 (§8 PR order) → rewritten to the actual T1–T12, noting T3 precedes T4; R3#4 (opaque cursor) → a shared `core/network` `fetchAllPages` helper URI-encodes the cursor (`Uri.encodeQueryComponent`), used by T2 + T3, with a `+`/`/` cursor test asserting `cursor=a%2Bb%2Fc%3D%3D`.
```
