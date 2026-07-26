# Phase 4a Flutter — Task Authoring & Matching Client (Design)

> Part of the Supabase → Go API + VPS refactor. Program strategy:
> `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md`;
> Phase 0 baseline `docs/superpowers/specs/2026-07-22-phase0-baseline.md`.
> This is the **Flutter follow-on** to the Phase 4a **backend** spec
> `docs/superpowers/specs/2026-07-25-phase4a-task-authoring-matching-design.md`
> (its §7 API contract is the source of truth for the endpoints consumed here)
> and its companion `docs/superpowers/specs/2026-07-25-phase4a-follow-ups.md`.
>
> Each phase is its own `spec → plan → implementation` cycle; this document
> covers **Phase 4a Flutter only**. The implementation plan is produced
> separately by the writing-plans workflow and is not committed.
>
> **Design-ahead:** as of writing, the integration branch `refactor/go-api-vps`
> has Phase 1 + Phase 2 merged; Phase 3a and Phase 4a **backend** are designed
> but not yet implemented. This spec targets the Phase 4a backend §7 contract and
> the Phase 3a Flutter client foundation (`ApiClient` write verbs, the `AppUser`
> current-user contract, the `PresignedUploadClient`/`me_repository` patterns),
> both of which land before this plan executes.

---

## §0 Scope & Context

Phase 4a ("task authoring + matching") is the first task-lifecycle slice. The
backend spec ported the server side (Go `service`/`store`/`handler`/worker, async
matching, availability, notification-send foundation). **This document is the
Flutter client** that consumes that backend, mirroring the Phase 2/3a
backend-then-Flutter split.

**Porting philosophy (locked, inherited):** behavior- and concept-preserving
port; only the *structure* is redesigned (Option E layout, `ApiClient` instead of
the Supabase SDK, DTOs mirroring the HTTP contract). Clearly-poor client
implementations may be improved during the port as long as intent is preserved;
anything dropped or deferred is recorded in §10.

**Transitional narrowing (Phase 2/3a principle):** on the integration branch, the
downstream lifecycle (evidence → 4b, judgement → 4c) and the point/reward system
(Phase 5) are not migrated. 4a Flutter makes **task authoring + matching + referee
availability** work end-to-end against the Go API; downstream sections remain
non-functional until their phase, which is expected and accepted.

### In scope

- **Task authoring** — create / edit / delete a draft; **publish** (a first-class
  verb now, `{ refereeCount }`).
- **Home** — the tasker's own task list and the referee's assignment list.
- **Task detail (4a portions)** — task info + referee-request states + referee
  cancel; the screen straddles 4b/4c/report (§2.4, P4aF-D3).
- **Referee availability** — weekly time slots + blocked dates (mounted on the
  Profile screen).
- **Referee-request cancel** — before cutoff → re-match.
- **Matching config read** — `GET /matching/config` for the cancel-cutoff (§2.2).
- **Matching notifications** — the 5 loc-keys already exist client-side; verify
  only (§2.6).
- **A shared `core` progressive poller** — extracted for the async-matching
  refresh, reusable across the app (§2.7, P4aF-D6).

### Out of scope (deferred, narrowing)

- **evidence** submission / private-R2 download UI → Phase 4b.
- **judgement** / rating / threads UI → Phase 4c.
- **reports** UI (`report_menu_button`) → deferred within Phase 4 (its entry
  points live inside task/evidence/judgement screens; hidden in 4a, §2.4).
- **Point cost / wallet / affordability UI** in the publish flow → Phase 5
  (P4aF-D1). The point system (`billing`) is not migrated in 4a.
- **`referee_availability` `is_accepting` / `max_concurrent` editing UI** → the
  imminent availability-cap feature (backend adds the table + matching
  enforcement only; no editing endpoint in 4a).
- **IAP/subscription progressive-poll retrofit** onto the new shared poller →
  Phase 5 (billing/IAP migrates then; §2.7).

---

## §1 Decision Log

| ID | Decision | Rationale |
|----|----------|-----------|
| **P4aF-D1** | **Publish screen = an explicit referee-count selector (1..config `maxRefereesPerTask`); send `{ refereeCount }`. Remove all point cost / balance / affordability UI from the publish flow.** Drop the `billing` `get_point_for_matching_strategy` read. The old "matching-strategy selector" widget (which doubled as an implicit count picker and rendered `Npt`) is rebuilt as a count selector. | The point system (`billing`) is not migrated until Phase 5, the backend publish point-lock is a no-op stub in 4a, and the Supabase wallet balance is being torn down — so a cost/affordability UI in 4a would be misleading and depend on removed code. A plain count selector is the least-surprising narrowing; cost/balance re-integrate in Phase 5. Backend collapses `matching_strategy` to a single `standard` and takes an explicit `refereeCount`, so the strategy selector has no remaining product meaning. |
| **P4aF-D2** | **Async-matching UX = client-side progressive polling** (`[1,1,2,2,3]s`, the established IAP cadence) while any request is `pending`, plus the existing pull-to-refresh / `onResume` invalidation. **FCM drives notification display only** — the FCM receipt is **not** wired to provider invalidation. Screen/data updates are **always** sourced from the Go API. No Realtime. | Backend D3 made matching async (publish → `pending`, worker matches a moment later), so the tasker now sees `pending` immediately where the old DB trigger showed a completed match synchronously. Polling smoothly surfaces the `pending → accepted` transition in-screen; FCM (best-effort, permission-gated, possibly delayed) is a *nudge to look*, not a UI-correctness path. A true server-push (SSE/WebSocket) would require api↔worker coordination (e.g. `LISTEN/NOTIFY`) + persistent connections through Caddy — unjustified operational complexity at pre-launch, single-VPS scale for one transition. Keeping the API the single source of refresh keeps correctness independent of push delivery. |
| **P4aF-D3** | **Task detail straddles phases; migrate the 4a portions only; the downstream sections are NOT mounted in 4a.** Migrate task info + referee-request states + cancel to the Go API, and migrate the "am I the tasker / the assigned referee" **role check to the Phase 2 `AppUser` (internal UUID) contract**. The evidence (4b), judgement (4c), evidence-timeout, and report sections are **not mounted** in 4a — their mount points remain in the screen as commented markers (`// Phase 4b`/`4c`) re-activated in those phases. **Completion criterion:** `task_detail_screen.dart` and its 4a widgets carry **zero `supabase_flutter` import** and opening a matched task triggers no Supabase call. **Refinement of brainstorming decision 3 (2026-07-26 review):** the earlier "render empty (no Go data)" plan does not remove Supabase — `JudgementSection` / `EvidenceSubmissionSection` read `Supabase.instance.client.auth` *before* their empty-state branch, and an accepted request makes the evidence gate mount them. Not-mounting is the clean way to keep the straddle shell while executing no Supabase path; it stays consistent with the chosen "preserve the composition, downstream non-functional until its phase" intent. | Matches the Phase 2/3a narrowing precedent. The role check via Supabase auth is *already* broken post-Phase-2, so moving it to `AppUser` is required regardless. Not-mounting avoids editing the 4b/4c-owned widgets (scope creep) while guaranteeing no live Supabase reference. |
| **P4aF-D7** | **The consumed wire contract is pinned in the backend spec §7.1 (camelCase JSON) before Flutter DTOs are written**, and task/assignment responses **embed a minimal `PublicProfile`** (`userId`, `username`, `avatarUrl`) for the tasker and each matched referee. The Flutter side introduces a `PublicProfile` domain + DTO (the Phase-3a-deferred other-user profile), and `Task.tasker` / `RefereeRequest.referee` become `PublicProfile?`. DTOs are **camelCase** (matching the Go API), replacing the old snake_case PostgREST `@JsonKey` mapping. | The review found §7 too coarse to write DTOs test-first, and the home cards / referee cards / detail display avatar+username from the aggregated profile — deleting the PostgREST reshaping requires the Go API to return that profile explicitly. Pinning the contract + embedding the minimal projection makes the DTO tasks executable and keeps the display working without a separate per-user fetch. |
| **P4aF-D4** | **Backend-mirroring client cleanups:** drop `Task.feeAmount` / `Task.feeCurrency` (backend drops the columns; already dead in the client); remove `matching_strategy` from the client (single `standard`; the selector is gone) and `RefereeRequest.preferredRefereeId`; remove `matched` / `declined` from the client's request-status derivation. The referee-side `'synthetic-id'` fake `RefereeRequest` hack (`fetchActiveRefereeTasks`) is resolved by the real request row returned by `GET /me/assignments`. | Keeps the client contract aligned with the reshaped backend; removes dead/foreign fields and a fragile placeholder. Dropped states/columns are recorded in the backend follow-up doc. |
| **P4aF-D5** | **Restructure the touched features (`task`, `matching`, `home`) to the Option E layout** (`data/ domain/ application/ ui/`, `*ViewModel` notifiers, DTOs in separate files) as opportunistic refactoring while their data layer is rewritten — mirroring Phase 3a's `profile`/`notification` restructure. Scoped to the migrated features, not a repo-wide rename. | Strategy §15 — improve code you are already touching. Today these use `presentation/` + `*Controller`; Option E brings them in line with `features/auth` and the Phase 3a features. |
| **P4aF-D6** | **Extract a shared, provider-neutral progressive poller into `core`** (`lib/core/async/progressive_poller.dart`), consumed by matching in 4a. **Do not retrofit the existing IAP/subscription poller in 4a** (billing/IAP migrates in Phase 5, which adopts the shared poller then). | The `[1,1,2,2,3]s` cadence now has ≥2 consumers (IAP subscription refresh + matching); a single primitive removes duplication and standardizes cancellation/backoff. Retrofitting IAP now would pull Phase-5 billing code into 4a scope; deferring keeps the phase boundary clean while still delivering the shared abstraction. |

---

## §2 Feature Design

Global constraints (inherited from Phase 2/3a Flutter):

- **One HTTP client for JSON:** features call `ApiClient`
  (`lib/core/network/api_client.dart`; Phase 3a added `patchJson`/`postJson`/
  `putJson`/`deleteJson`); no feature builds its own Dio.
- **Retry policy:** only idempotent GET auto-retries once on 401;
  `POST`/`PATCH`/`PUT`/`DELETE` never auto-retry (Phase 2).
- **`supabase_flutter` must not be imported** by `task` / `matching` / `home`
  after this plan (CI architecture import check, extending the Phase 2/3a rule).
- **`firebase_auth` only in `features/auth`** (unchanged). Role checks read the
  Phase 2 `AppUser` current-user contract, not Firebase/Supabase directly.
- **DTOs are separate files** mirroring the HTTP contract; the repository maps
  DTO ↔ domain; domain never imports DTOs.
- **No `update` method name** on any `AsyncNotifier`-based `*ViewModel`
  (project rule — `invalid_override`); use domain-specific names.
- **Spacing** uses `SizedBox` (not per-item `Padding`); use `AppSizes`
  constants, never hardcoded pixels (project rules).
- Referee is shown with the localized referee label in the UI (unchanged);
  internal identifiers stay English `referee`.

### 2.1 `task` — authoring & publish

Rewrite `data/task_repository.dart` onto `ApiClient`; restructure to Option E.

- `POST /tasks` — create a draft (`{ title, description?, criteria?, dueDate? }`).
- `PATCH /tasks/{id}` — edit own draft.
- `DELETE /tasks/{id}` — delete own draft.
- `POST /tasks/{id}/publish` — **new first-class verb**, body `{ refereeCount }`,
  returns `{ taskId, status: "open", requests: [{ id, status: "pending" }] }`.
- `GET /tasks/{id}` — task detail + referee-request states.
- `GET /me/tasks` — own authored tasks (status filter, paging).

Changes:

- **Publish is separated from the status selector.** Today "publish" is
  implicitly "set status `open` and save via `update_task`". The new UI keeps a
  draft save (`POST`/`PATCH`) and a distinct **Publish** action that calls
  `POST /tasks/{id}/publish` with the chosen `refereeCount` (P4aF-D1). Draft
  open-requirement validation (title, criteria, `dueDate` lead time) is
  server-authoritative; the client keeps a fast pre-check but surfaces the
  server's `400` on failure.
- **Referee-count selector** replaces the strategy selector: 1..N where **N =
  `matchingConfigProvider.maxRefereesPerTask`** (default 2), not a hard-coded 2
  (review item 3). While the config is loading, the selector is disabled (or caps
  at 1); if a previously-selected count exceeds a newly-loaded max, it is clamped
  down. This prevents the client sending `refereeCount: 2` when the server cap is
  1. No `Npt` cost, no balance gate (P4aF-D1).
- `Task` domain drops `feeAmount` / `feeCurrency` and no longer carries
  `matching_strategy` (P4aF-D4). DTOs are **camelCase** (matching the Go API,
  P4aF-D7): `TaskDto`, `RefereeRequestDto`, and a `PublicProfileDto` mirror
  §7.1's JSON; the manual PostgREST join-reshaping (`judgements`→`judgement`,
  `profiles`→`referee`) and the old snake_case `@JsonKey` mapping are deleted.
  `Task.tasker` / `RefereeRequest.referee` become `PublicProfile?` (P4aF-D7).
- Status-derivation (`getDetailedStatuses`) is kept but pruned: `matched` /
  `declined` removed; evidence/judgement-derived states become inert in 4a (no
  data) and are re-enabled in 4b/4c.

### 2.2 `matching` — availability, cancel, config

Rewrite `data/matching_repository.dart` onto `ApiClient`; restructure to Option E.

- **Time slots:** `GET/POST/PUT/DELETE /me/availability/time-slots`. Domain
  `RefereeAvailableTimeSlot` (dow, startMin, endMin, isActive) unchanged. The
  read continues to show active slots; the active/inactive toggle UI stays
  deferred (matches the backend "editing deferred" stance).
- **Blocked dates:** `GET/POST/PUT/DELETE /me/availability/blocked-dates`. Domain
  `RefereeBlockedDate` (startDate, endDate, reason?) unchanged.
- **Cancel:** `POST /referee-requests/{id}/cancel` (assigned referee only, before
  cutoff → re-match). Replaces the Supabase `cancel_referee_assignment` RPC.
- **Cancel cutoff via config (P4aF-D2/config):** replace the hard-coded
  `kRefereeCancelDeadlineHours = 12` client mirror with a read of
  `GET /matching/config` (`cancel_deadline_hours`), cached; the button visibility
  computes the cutoff from the fetched config. Server remains authoritative (the
  cancel `POST` still rejects past-cutoff); the config read only removes client
  drift. `matching_constants.dart` is removed (or reduced to non-deadline
  constants if any remain).
- `RefereeRequest` domain drops `preferredRefereeId` (P4aF-D4).

### 2.3 `home` — task list & assignment list

- `activeUserTasksProvider` → `TaskRepository.fetchMyTasks()` (`GET /me/tasks`);
  `activeRefereeTasksProvider` → **`MatchingRepository.fetchMyAssignments()`**
  (`GET /me/assignments`) — assignments are a matching-owned resource, so the call
  lives in `MatchingRepository`, not `TaskRepository` (review item 4); the matching
  repository foundation is therefore built **before** home consumes it. Both via
  `ApiClient`; Supabase removed.
- The referee assignment list now carries **real request rows** (id, status,
  matched referee) with the embedded `tasker` `PublicProfile` from
  `GET /me/assignments`, deleting the `'synthetic-id'` placeholder (P4aF-D4).
- Existing refresh triggers (pull-to-refresh, `AppLifecycleListener.onResume`
  invalidation) are preserved. The publish → pending → accepted transition adds
  progressive polling (§2.7 / §3).

### 2.4 Task detail straddle (P4aF-D3)

`task_detail_screen.dart` composes 4a and downstream sections. In 4a:

- **Migrated (Go API):** `task_detail_info_section`, `tasker_referees_section`
  (request states), `withdraw_matching_button` (cancel), and the current-user /
  role check.
- **Role check → `AppUser`:** replace every `Supabase.instance.auth` /
  Supabase-uid comparison ("am I the tasker / the assigned referee") with the
  Phase 2 current-user contract (internal UUID). This is required, not optional
  (the Supabase auth path is gone post-Phase-2).
- **Downstream sections (evidence 4b / judgement 4c / evidence-timeout):** **not
  mounted** in 4a (P4aF-D3). Their mount points stay as commented markers
  (`// Phase 4b`/`4c`) and return when those phases migrate the widgets to the Go
  API. This is required (not just cosmetic): `JudgementSection` /
  `EvidenceSubmissionSection` read `Supabase.instance.client.auth` before their
  empty-state branch, and an accepted request would otherwise mount the evidence
  section — so "render empty" cannot avoid a live Supabase call; not-mounting can.
- **Report menu:** not mounted in 4a.
- **Completion criterion:** `grep supabase_flutter` over `task_detail_screen.dart`
  and its 4a widgets is empty; opening a matched task issues no Supabase call.

### 2.5 Current-user / role (concrete)

Today role decisions read the **Supabase auth uid** directly, scattered across
widgets:

```dart
// task_detail_screen.dart
if (Supabase.instance.client.auth.currentUser?.id == displayTask.taskerId) ...
// withdraw_matching_button.dart — each widget resolves it itself
final userId = Supabase.instance.client.auth.currentUser?.id;
for (final r in task.refereeRequests) { if (r.matchedRefereeId == userId) return r; }
```

**Why the swap is a drop-in:** after Phase 2 + the 4a backend, `task.taskerId`
and `refereeRequest.matchedRefereeId` are **internal UUIDs** (`users(id)`), and
the Phase 2 `AppUser.internalUserId` is that same internal UUID — the ID spaces
match, so only the *source* of the current id changes.

**Target — hybrid (pure derivation + a thin provider).** The derivation is a
**pure, Riverpod-neutral** function on the domain (unit-testable without a
container); a thin `taskRoleProvider` **composes** the two async sources and
delegates to it, and the (already-`Consumer`) widgets `ref.watch` the provider —
no prop-drilling, and the role stays live-correct as polling updates the task.

```dart
// lib/features/task/domain/task_viewer_role.dart  (the tested core — no Riverpod)
class TaskViewerRole {
  final bool isTasker;
  final RefereeRequest? myRequest;          // the request matched to me, or null
  const TaskViewerRole({required this.isTasker, required this.myRequest});
  bool get isAssignedReferee => myRequest != null;
}
extension TaskRoleX on Task {
  TaskViewerRole viewerRole(String? internalUserId) {
    if (internalUserId == null) return const TaskViewerRole(isTasker: false, myRequest: null);
    return TaskViewerRole(
      isTasker: taskerId == internalUserId,
      myRequest: refereeRequests
          .where((r) => r.matchedRefereeId == internalUserId).firstOrNull,
    );
  }
}

// lib/features/task/ui/task_role_provider.dart  (thin — no logic, just composition)
@riverpod
Future<TaskViewerRole> taskRole(Ref ref, String taskId) async {
  final task = await ref.watch(taskDetailProvider(taskId).future); // §2.7 owner
  final me   = await ref.watch(currentAppUserProvider.future);     // Phase 2 contract
  return task.viewerRole(me?.internalUserId);                      // delegate to the pure fn
}

// widgets (already ConsumerWidgets) watch it directly — no params threaded down:
final role = ref.watch(taskRoleProvider(taskId));
role.whenData((r) { if (r.isTasker) /* mount TaskerRefereesSection */ });
// WithdrawMatchingButton reads taskRoleProvider(task.id).myRequest itself.
```

- **Not over-engineering here:** the role is needed by ~3 detail-tree widgets that
  are already `Consumer`s and composes two async sources — a provider removes
  prop-drilling and unifies `loading`/`error` as `AsyncValue`, matching how the
  task itself is consumed. The derivation logic stays in the **pure function**
  (keeping the provider a ~5-line delegate and the logic container-free testable);
  it would only be over-engineering if the logic lived *in* the provider or the
  role were needed in a single place.
- **Composition ordering:** `taskRoleProvider` watches `taskDetailProvider` (the
  §2.7 poll-state owner) + `currentAppUserProvider`, so the poller + `taskDetail`
  notifier are built **before** the role provider and the detail-screen migration.
- **Single source:** `currentAppUserProvider` (`AsyncValue<AppUser?>`,
  `features/auth`). The detail screen is post-login, so `internalUserId` is
  available; the `loading` / `null` case degrades to "no role-specific sections".
- **Pure derivation → unit-testable** without Riverpod (tasker / assigned-referee
  / neither branches).
- **Repository-side auth reads vanish:** the `_client.auth.currentUser?.id` uses
  in `task_repository` (own-task filter; the synthetic-request self-id injection)
  disappear because `GET /me/tasks` / `GET /me/assignments` scope by the
  server-side `CurrentUser` — the client no longer supplies its own id.
- No new endpoint; `GET /api/v1/me` (Phase 2) already provides identity.

### 2.6 Notifications (verify-only)

- The 5 matching loc-keys already resolve client-side via
  `notification/application/notification_text_resolver.dart` and the generated
  `slang` catalog: `notification_request_matched_tasker`,
  `notification_task_assigned_referee`,
  `notification_matching_reassigned_tasker`,
  `notification_matching_cancelled_pending_tasker`,
  `notification_matching_expired_refunded_tasker` (each `_title` / `_body`).
- **4a Flutter adds no new i18n.** Verify the `locArgs` ordering
  (`[0]`=taskTitle, `[1]`=deadline) matches what the Go `send_notification`
  worker emits (backend §8). The FCM **token-sync** path is Phase 3a's concern,
  not re-touched here. FCM stays notification-display only (P4aF-D2).

### 2.7 `core` progressive poller (P4aF-D6)

A provider-neutral primitive extracted to `lib/core/async/progressive_poller.dart`:

```dart
/// Polls [fetch] on a backoff [schedule] until [isDone] or cancellation.
/// After the schedule is exhausted, polling stops (bounded, no infinite loop).
Future<T> pollUntil<T>({
  required Future<T> Function() fetch,
  required bool Function(T) isDone,
  List<Duration> schedule = kDefaultProgressiveSchedule, // [1,1,2,2,3]s
  CancellationToken? cancel, // stop on screen dispose / navigation away
});
```

- **Matching consumer — state owner (P4aF-D2, review-refined):** the poll runs on
  the **task-detail screen only** (not `home`; home keeps pull-to-refresh /
  `onResume` invalidation + the FCM nudge — polling every home card is heavier and
  unnecessary). The existing `taskProvider(id)` is a read-only `FutureProvider`,
  so it cannot hold poll-updated state; 4a introduces a **`taskDetail` codegen
  `AsyncNotifier` family** (`@riverpod class TaskDetail extends _$TaskDetail`,
  family-keyed by `taskId`) that owns the task state. Its `pollUntilMatched()`
  runs `pollUntil(fetch: repo.getTask(taskId), isDone: (t) => t.refereeRequests
  .every((r) => r.status != 'pending'))` and, **per Riverpod v3**, guards every
  post-`await` write with `if (!ref.mounted) return;` before `state = AsyncData(t)`
  and cancels the `CancellationToken` via `ref.onDispose(token.cancel)` (verified
  against the Riverpod v3 docs — `ref.mounted`, `ref.onDispose`). The poll is
  bounded by the schedule and cancelled on dispose; it starts after a successful
  publish and when opening a still-`pending` task.
- **IAP retrofit deferred to Phase 5** (P4aF-D6): the existing
  `in_app_purchase_controller` poller is left untouched in 4a and adopts this
  primitive when billing/IAP migrates.

---

## §3 Async-Matching UX (detail)

Old behavior: publish ran matching synchronously in a DB trigger, so returning to
`home` showed an already-matched task. New behavior: publish returns `pending`;
the worker matches shortly after.

Client flow after a successful publish:

1. Publish returns `{ status: "open", requests: [pending…] }`; the UI shows the
   task as matching in progress (`pending`).
2. The **progressive poller** (§2.7) runs `[1,1,2,2,3]s`, re-fetching until every
   request leaves `pending` (→ `accepted` or, past cutoff, `expired`), or the
   schedule ends, or the user leaves the screen (cancellation).
3. On `accepted`, the referee card / status updates in-place to show that a
   referee was found.
4. If the schedule ends still-pending (rare; slow worker/outage), the user can
   pull-to-refresh, and `onResume` re-invalidates on return; the FCM
   `request_matched_tasker` push (backend-sent) nudges the user to reopen.

Data correctness is always API-sourced; FCM is display-only (P4aF-D2). No
Realtime, no `LISTEN/NOTIFY`, no api↔worker push channel.

---

## §4 API Contract Consumed (mirror of backend §7)

| Method & path | Purpose | Client site |
|---------------|---------|-------------|
| `POST /tasks` | create draft | task_repository |
| `PATCH /tasks/{id}` | edit own draft | task_repository |
| `DELETE /tasks/{id}` | delete own draft | task_repository |
| `POST /tasks/{id}/publish` | publish → pending (`{refereeCount}`) | task_repository |
| `GET /me/tasks` | own authored tasks | home |
| `GET /tasks/{id}` | task detail + request states | task detail |
| `GET /me/assignments` | tasks the caller referees | home |
| `POST /referee-requests/{id}/cancel` | cancel assignment → re-match | matching |
| `GET/POST/PUT/DELETE /me/availability/time-slots` | weekly slots | matching |
| `GET/POST/PUT/DELETE /me/availability/blocked-dates` | blocked dates | matching |
| `GET /matching/config` | deadline settings (cancel cutoff) | matching |

All errors use the Phase 2 stable envelope `{ error: { code, message, requestId } }`
→ `ApiException`. `GET /api/v1/me` (identity) is Phase 2, unchanged.

---

## §5 Option E Restructure (P4aF-D5)

Per feature, while the data layer is rewritten (`presentation/` + `*Controller`
→ `data/ domain/ application/ ui/` + `*ViewModel`, DTOs separate):

```
lib/features/task/
  domain/task.dart                     # no feeAmount/feeCurrency/matching_strategy
  domain/task_creation_request.dart    # + refereeCount on publish
  data/task_dto.dart                    # mirrors Go JSON (no PostgREST reshaping)
  data/task_repository.dart             # ApiClient-backed; no supabase_flutter
  application/…                         # publish orchestration if warranted
  ui/task_creation_screen.dart
  ui/task_creation_view_model.dart      # was *Controller
  ui/task_detail_screen.dart
  ui/task_detail_view_model.dart
  ui/widgets/…                          # referee-count selector replaces strategy
lib/features/matching/
  domain/referee_request.dart           # drop preferredRefereeId
  domain/referee_available_time_slot.dart / referee_blocked_date.dart
  data/*_dto.dart + matching_repository.dart  # ApiClient; no supabase_flutter
  data/matching_config_dto.dart          # GET /matching/config
  ui/…_view_model.dart / widgets/…
lib/features/home/
  ui/home_view_model.dart                # lists via task/matching repos (no poll; poll is detail-only)
lib/features/task/ui/task_detail_view_model.dart  # AsyncNotifier owner; runs the poll (detail-only)
lib/core/async/progressive_poller.dart   # shared (P4aF-D6)
```

Follow the existing `features/auth` and the Phase 3a `profile`/`notification`
structure as templates.

---

## §6 Transitional Narrowing — "runnable" after 4a Flutter

On the integration branch, after this plan the app:

- ✅ builds and launches; signs in and resolves the internal user (Phase 2);
  profile / FCM-token work (Phase 3a);
- ✅ **task authoring** works via the Go API: create/edit/delete a draft, publish
  (→ pending), see it become accepted (progressive polling);
- ✅ **home** shows own tasks and referee assignments from the Go API;
- ✅ **referee availability** (time slots / blocked dates) editable via the Go API;
- ✅ **cancel** an assignment before cutoff → re-match;
- ⏸ **evidence / judgement / reports / points** remain non-functional until their
  phases (expected, §0). Their sections of the task-detail screen are **not
  mounted** in 4a (re-mounted in 4b/4c); the report menu is not mounted.

`Supabase.initialize(...)` **remains** in startup for still-un-migrated features;
`task` / `matching` / `home` stop importing `supabase_flutter` (CI import check).

---

## §7 Testing & CI

**Flutter unit / widget:**

- **task:** `TaskDto` ↔ `Task` mapping (no fee/strategy fields); repository calls
  (`POST/PATCH/DELETE /tasks`, `POST /tasks/{id}/publish` **sends `refereeCount`**,
  `GET /tasks/{id}`, `GET /me/tasks` **paging over `nextCursor`**) against a fake
  `ApiClient`; publish view-model happy path + server `400` open-requirement
  error; referee-count selector bounds (**1..config `maxRefereesPerTask`**, clamp
  + loading).
- **status derivation:** `Task.getDetailedStatuses` on the **4a data shape**
  (`judgement`/`evidence` always null), **pending-first** (matches the poll's
  `isDone`) — tasker: any pending → `matching`; else any accepted →
  `matching_complete`; else all expired → `matching_failed` (so `[accepted,
  pending]` → `matching`, not `matching_complete`); referee: `matching` (pending),
  `matching_complete` (accepted), inactive (expired). Must not infer `matching`
  from a null judgement. (Display state `matching_complete`, **not** the deleted
  request status `matched`.)
- **matching:** availability CRUD mapping + calls; cancel calls
  `POST /referee-requests/{id}/cancel`; cancel-button visibility uses the
  **config-fetched** cutoff (not a constant); `GET /matching/config` mapping.
- **home:** `GET /me/tasks` / `GET /me/assignments` mapping (**multi-page**); the
  assignment list carries real request rows (no `'synthetic-id'`).
- **progressive poller (core):** stops on `isDone`; stops when the schedule is
  exhausted (bounded); stops on cancellation (no poll after dispose); the
  matching consumer transitions pending → accepted and halts.
- **task detail:** role check reads `AppUser` via `taskRoleProvider` (tasker vs
  referee vs neither); evidence/judgement/report sections **not mounted**; opening
  a matched task issues **no Supabase call**.
- **Option E / rules:** each `*ViewModel` success/error; no `update` method name;
  `SizedBox` spacing / `AppSizes` (lint-guarded).

**CI gates:** dart format, `flutter analyze`, `flutter test`, **architecture
import checks** (`supabase_flutter` not imported by `task`/`matching`/`home`; Dio
construction only in `core/network`), flavored debug build
(`flutter build apk --debug -t lib/main_dev.dart`). Per project convention the PR
runs `flutter build` only; a **single emulator pass** runs at the end on the
integration branch (§9).

---

## §8 PR Breakdown

**One Flutter PR** into `refactor/go-api-vps` (operator preference — easier to
grasp as a unit); the branch stays buildable. Internal task ordering matches the
plan's **T1–T12** (see the plan for full detail):

1. **T1** domain cleanup — `PublicProfile`, `TaskViewerRole`, 4a status
   derivation, drop fee/strategy fields (+ type-ripple consumers).
2. **T2** task DTOs (camelCase) + repository over `ApiClient` (publish, paging).
3. **T3** matching repository foundation — config + assignments + cancel
   (`MatchingRepository` gains `ApiClient`, keeps Supabase for availability).
4. **T4** `home` lists over the Go API (consumes T2 + T3 — hence T3 precedes T4).
5. **T5** `task` Option E restructure + config-bounded referee-count publish UI.
6. **T6** `core` progressive poller.
7. **T7** `taskDetail` `AsyncNotifier` family + matching-result polling.
8. **T8** `taskRoleProvider` + task-detail role migration; downstream not mounted.
9. **T9** `matching` availability + Option E (removes Supabase from matching).
10. **T10** config-driven withdraw button (cancel).
11. **T11** matching notification loc-key verification.
12. **T12** CI import checks + full analyze/test + single emulator pass.

*Optional split* if review grows too large (mirrors the Phase 3a escape hatch):
split T1–T5 (task/home/matching data) from T6–T10 (poller/detail/availability).

**Depends on:** Phase 4a **backend** (endpoints live) and the Phase 3a **Flutter**
merge (`ApiClient` write verbs, `AppUser` current-user contract). Execute after
both are in place. Until then this is design-ahead.

---

## §9 Done Criteria (Phase 4a Flutter)

- [ ] A tasker can create / edit / delete a draft and **publish** (`refereeCount`)
      via the Go API; the task shows `pending`, then `accepted` via progressive
      polling (no manual refresh needed while on-screen).
- [ ] `home` shows own tasks (`GET /me/tasks`) and referee assignments
      (`GET /me/assignments`) with **real** request rows; no `'synthetic-id'`.
- [ ] A referee edits availability (time slots / blocked dates) and cancels an
      assignment before cutoff (→ re-match); the cancel cutoff comes from
      `GET /matching/config`.
- [ ] Task detail's role check reads the Phase 2 `AppUser` contract via
      `taskRoleProvider`; evidence / judgement / report sections are **not
      mounted**; no Supabase call is made when opening a matched task.
- [ ] `task` / `matching` / `home` follow the Option E layout and no longer
      import `supabase_flutter` (CI import check passes).
- [ ] The publish flow shows **no** point cost / balance UI (Phase 5 re-adds).
- [ ] The shared `core` progressive poller is bounded and cancelable; the matching
      consumer uses it; the IAP poller is untouched (Phase 5 retrofit).
- [ ] The 5 matching notification loc-keys resolve with correct `locArgs`.
- [ ] CI gates pass; a single emulator pass verifies the end-to-end flow.

**Not** 4a Flutter criteria: evidence, judgement, rating, reports UI, point
cost/wallet, availability accepting/concurrency editing, IAP poller retrofit.

---

## §10 Out of Scope / Follow-ups

- **evidence UI** → Phase 4b. **judgement / rating UI** → Phase 4c.
- **reports UI** → deferred within Phase 4 (entry points live inside
  task/evidence/judgement screens; hidden in 4a).
- **Point cost / wallet / affordability UI in publish** → Phase 5 (with the
  billing migration).
- **`referee_availability` accepting-toggle / concurrency-cap editing UI** → the
  imminent availability-cap feature.
- **IAP/subscription progressive-poll retrofit** onto the shared `core` poller →
  Phase 5.
- **Server-side notification localization** (backend follow-up) would let the
  client stop resolving loc-keys; out of scope here, tracked in the backend
  follow-up doc.
- **Active/inactive time-slot toggle UI** → whenever that editing feature ships
  (backend reads active slots only today).
