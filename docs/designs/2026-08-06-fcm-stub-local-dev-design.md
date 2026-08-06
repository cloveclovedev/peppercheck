# FCM Stub — Log-Only Local Notification Delivery

**Date:** 2026-08-06
**Issues:** #525 (this feature), #522 (parent — OSS local dev profile), #523 / #524 (siblings — Garage, Auth emulator)
**Status:** Approved

## Context

Push delivery uses Firebase Cloud Messaging (FCM), which — unlike Auth — has
**no usable local emulator** (the Emulator Suite does not deliver messages). So
the "push" leg of the zero-account OSS local profile (#522) cannot be a faithful
emulator; it is a **log-only stub** at the delivery boundary. Real push behavior
is verified only against real FCM (operator opt-in).

The delivery seam already exists and is small:

- `backend/internal/platform/fcm/fcm.go` defines the provider-neutral interface
  `Client { Send(ctx, tokens, Message) (SendResult, error) }` and two
  implementations: `client` (real, Admin SDK messaging over Application Default
  Credentials) and **`noopClient` via `NewNoop(logger)` — already log-only**
  (`logger.Warn("FCM not configured; notification dropped", …)`). The doc comment
  in that file already names a richer inspection stub as **#525**.
- Everything downstream depends only on `fcm.Client`: the worker's
  `notification.Sender.HandleSend` calls `s.fcm.Send`, and the `api` command
  already hardcodes `fcm.NewNoop` (the api never sends FCM — only the worker
  does). The single selection point is `buildFCMClient` in
  `cmd/peppercheck/main.go` (worker path).

### Current behavior (corrected)

`buildFCMClient` selects the noop when `FIREBASE_PROJECT_ID == ""`. In the
canonical local stack this **already happens for the worker**: `backend/compose.yaml`
passes `FIREBASE_PROJECT_ID` **only to the `api` service** (line 87); the `worker`
service's `environment` block (lines 120–134) does not include it, so
`config.Load()` sees an empty project id in the worker and `buildFCMClient`
returns `NewNoop`. (The api never sends FCM anyway — it hardcodes `NewNoop` — and
uses its project id only for auth-token verification.) So the local push path is
**already zero-account today**: the worker log-noops instead of erroring.

The gap is therefore not a broken default but a **weak one**: (1) the existing
`NewNoop` log is sparse — `Warn("FCM not configured; notification dropped",
titleLocKey, recipients)` — omitting body/args/data, so a developer can't see
*what* would have been sent; and (2) selection depends implicitly on the worker
compose block *happening to omit* `FIREBASE_PROJECT_ID`. If that var is ever
added to the worker (a copy-paste, an env unification) **while valid ambient
credentials are present** (a developer's `GOOGLE_APPLICATION_CREDENTIALS` or
`gcloud` ADC), the worker would build a real client and **actually send real
push** from a dev/local run — unintended real delivery, not merely a caught
error. (Without credentials the init error or a `Send` failure is caught by
`buildFCMClient` for non-production and falls back to `NewNoop`, so the danger is
specifically the *credentials-present* case.) #525 makes the log useful and the
intent explicit.

## Goals

- Developers can **see what would have been sent** (the loc-keys, args, data,
  recipient count) in structured logs, for local verification — the current
  sparse `NewNoop` log does not show this.
- Selection of stub-vs-real is **explicit and robust**, not dependent on the
  worker compose block omitting a var; real FCM stays a documented **operator
  opt-in**.
- The zero-account local path keeps working (it already does — see above) with
  no downstream changes: the `fcm.Client` interface and the worker/service stay
  untouched.

## Non-goals

- Real local push delivery (impossible — accept the fidelity gap).
- Flutter changes: `FcmService.initialize` already degrades gracefully
  (permission/token failures are caught), and `Firebase.initializeApp()` is
  covered by the demo dev-flavor config from #524. Token registration to the Go
  API still runs harmlessly; messages simply never arrive locally.
- The pre-existing deep-link key mismatch (backend sends `data.route`, the client
  tap handler reads `data.task_id`) — unrelated to the stub, filed as #535.
- The worker job contract / at-least-once idempotency (#464) — unchanged; only
  the delivery adapter at the boundary is swapped.

## Decision

### 1. A log stub in `platform/fcm`

Provide a log-only `Client` (enrich `noopClient`, or add `NewLogStub(logger)`)
that logs the full outgoing `Message` at a clear level — `TitleLocKey`,
`BodyLocKey`, `LocArgs`, the full `Data` **map (keys and values)**, and the
recipient count — then returns
an empty `SendResult` (no tokens pruned). Logging the `Data` **values** (not just
keys) is what actually lets a developer see what would have been sent — e.g. the
task route/id — and is what would surface the #535 route mismatch during local
testing; the payload is task routes/ids, not secrets. This is the "records sends
for inspection" stub the existing TODO anticipates, realized as structured logs
(the operator's chosen shape). The SDK messaging types stay inside `platform/fcm`.

### 2. Make the worker selection explicit and add a documented opt-in

Keep the log stub as the worker's local default (it already is), but make the
intent explicit rather than implicit-by-omitted-var:

- `Env == "local"` → **log stub by default** (zero-flag). Real FCM locally is an
  **operator opt-in**: set an explicit flag (e.g. `FCM_DELIVERY=real`) **and**
  provide the worker `FIREBASE_PROJECT_ID` + `GOOGLE_APPLICATION_CREDENTIALS`
  (the worker compose block does not pass these today, so this is a new,
  documented path — not something that can happen by accident).
- `Env == staging | production` → **non-local selection is unchanged**. Today
  `buildFCMClient` treats a missing project id / `fcm.New` failure as **fatal
  only for `production`** (`main.go:214, 222`); **`staging` warns and falls back
  to `NewNoop`**. #525 does **not** alter this — it only changes the *local*
  branch. (If staging should instead require real FCM, that is a separate,
  explicit fail-closed change with its own verification, out of scope here.)
- The `api` path keeps `fcm.NewNoop` (unchanged).

Selecting by `Env` (not by whether `FIREBASE_PROJECT_ID` is empty) removes the
fragility: a local run **never sends real push** regardless of what project id or
ambient credentials happen to be present, unless explicitly opted in — so adding
that var (with a developer's ADC already in the environment) can't cause
unintended real delivery. Update `backend/.env.example` / `compose.yaml`
comments to describe this (local logs; explicit opt-in for real FCM).

### 3. Flutter — no change

Nothing is required client-side. The token still registers (or no-ops when
signed out); no message arrives locally; failures are already swallowed.

## Alternatives considered

- **Keep the implicit empty-`FIREBASE_PROJECT_ID` → noop selection** (do nothing
  but enrich the log). This already yields the local noop today because the
  worker compose block omits the var. Acceptable, but fragile: stub-ness is
  inferred from an *absent* env var rather than declared, so adding
  `FIREBASE_PROJECT_ID` to the worker while a developer's ambient ADC is present
  would flip local delivery to a real client that **actually sends real push** —
  the kind of implicit-config brittleness #483 warned about. Explicit `Env`-based
  selection is preferred; enriching the log alone would be a valid smaller scope
  if the explicit selector is deferred.
- **A `NOTIFICATIONS_ENABLED=false` boolean.** Rejected — a delivery selector
  (`stub` vs `real`) reads better than a disable flag and mirrors the
  local-default / operator-opt-in shape of the sibling legs.
- **In-memory recording adapter with an inspection endpoint.** Deferred —
  log-only was chosen as sufficient; a recording adapter can be added later if a
  test needs to assert on sent notifications.

## Consequences

- The local notification path already completes today (the worker log-noops);
  #525 makes that log **informative** (loc-keys/args/data/recipient count) and
  the selection **explicit** so it can't silently flip to a real client.
- Real delivery and tap/deep-link behavior are verified only against real FCM
  (operator opt-in) — the accepted fidelity gap.
- `backend/.env.example` / `compose.yaml` notification comments are corrected to
  match reality (worker log-noops locally; documented opt-in for real FCM).

## Deferred / related work

- #523 Garage (storage) and #524 Auth emulator — the other legs of the
  zero-account profile (#522); this reuses their local-default / operator-opt-in
  pattern.
- The deep-link key mismatch (`data.route` vs `data.task_id`) — filed as #535.
- #464 worker idempotency — unchanged.

## References

- `backend/internal/platform/fcm/fcm.go` (`Client`, `NewNoop`, `New`,
  `buildMulticast`)
- `backend/cmd/peppercheck/main.go` (`buildFCMClient`, the api noop injection)
- `backend/internal/notification/sender.go` (`HandleSend`, `JobKindSendNotification`)
- `backend/internal/core/config/config.go` (`Env`, `FirebaseProjectID`)
- `backend/.env.example` (`FIREBASE_PROJECT_ID=peppercheck-local` dummy)

## Decision log

- **2026-08-06** — Initial design. The delivery seam (`fcm.Client` + a log-only
  `NewNoop`) already exists; #525 adds a richer log stub and selects it
  explicitly for `Env == local`, with real FCM as an operator opt-in. Flutter
  needs no change. Design-doc-only; implementation stays in #525. Deep-link key
  mismatch split to #535.
- **2026-08-06** — Corrected after a Codex round on PR #536 (P2). The original
  "gotcha" premise was wrong: `compose.yaml` passes `FIREBASE_PROJECT_ID` **only
  to the `api`**, not the `worker`, so the worker already sees an empty project id
  and `buildFCMClient` already returns `NewNoop` — the local push path is already
  zero-account (it log-noops, it does not error at `Send`). Reframed #525's value
  as (1) enriching the sparse `NewNoop` log to show the full payload and (2)
  making selection **explicit by `Env`** so it can't silently flip to a real
  client if `FIREBASE_PROJECT_ID` is ever added to the worker, plus a documented
  real-FCM-local opt-in (which requires giving the worker the project id + ADC —
  a path that does not exist today).
- **2026-08-06** — Second Codex round on PR #536 (P2). Corrected another "as
  today" overclaim: `buildFCMClient`'s fatal branch is `production`-only
  (`main.go:214, 222`); `staging` currently warns and falls back to `NewNoop`.
  Clarified that #525 changes only the *local* branch and leaves non-local
  selection unchanged; making staging require real FCM would be a separate,
  explicit fail-closed change, out of scope.
- **2026-08-06** — Third Codex round on PR #536 (P2 ×2). (1) Reframed the
  explicit-selector rationale: the real risk of adding `FIREBASE_PROJECT_ID` to
  the worker is **accidental real push when ambient credentials are present**
  (a caught init/`Send` error is not the danger — that falls back to `NewNoop`
  for non-production). (2) The log stub must log the `Data` **map values**, not
  just keys, or "see what would have been sent" (and surfacing #535) is not met.
