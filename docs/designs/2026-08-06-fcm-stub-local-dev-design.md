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

### The gotcha this fixes

`buildFCMClient` selects the noop only when `FIREBASE_PROJECT_ID == ""`. But
`backend/.env.example` ships `FIREBASE_PROJECT_ID=peppercheck-local` (a non-empty
dummy), so local dev **skips** the noop branch and builds a **real** client via
`fcm.New("peppercheck-local")`, which succeeds at construction and only fails at
`Send` time with a network/credentials error. So zero-account local dev is **not**
the default today for notifications — the worker attempts real FCM and errors.
This is the strongest reason to select the stub **explicitly** (by environment)
rather than by an empty-string fallback — the same lesson as Garage/#483.

## Goals

- The notification path **runs to completion locally with zero external accounts**
  — enqueue → worker → delivery → (log), no real FCM credentials required.
- Developers can **see what would have been sent** (the loc-keys, args, data,
  recipient count) in structured logs, for local verification.
- **Explicit** stub-vs-real selection; real FCM stays the **operator opt-in**.
- No downstream changes: the `fcm.Client` interface and the worker/service are
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
`BodyLocKey`, `LocArgs`, the `Data` keys, and the recipient count — then returns
an empty `SendResult` (no tokens pruned). This is the "records sends for
inspection" stub the existing TODO anticipates, realized as structured logs
(the operator's chosen shape). The SDK messaging types stay inside
`platform/fcm`.

### 2. Explicit selection at `buildFCMClient` (worker)

Select the delivery adapter by environment, not by empty project id:

- `Env == "local"` → **log stub by default** (zero-flag), with an **operator
  opt-in** flag (e.g. `FCM_DELIVERY=real`) to use real FCM locally.
- `Env == staging | production` → **real FCM** (build error stays fatal, as
  today).
- The `api` path keeps `fcm.NewNoop` (unchanged).

This makes the stub the local default regardless of the dummy
`FIREBASE_PROJECT_ID`, closing the gotcha above. Update `backend/.env.example`
and `compose.yaml` comments to describe the real behavior (local logs; opt-in
for real FCM).

### 3. Flutter — no change

Nothing is required client-side. The token still registers (or no-ops when
signed out); no message arrives locally; failures are already swallowed.

## Alternatives considered

- **Rely on the empty-`FIREBASE_PROJECT_ID` → noop fallback.** Rejected — the
  shipped `.env.example` sets a non-empty dummy, so the fallback never triggers;
  inferring stub-ness from emptiness is exactly the brittle pattern #483 warned
  about. Explicit environment-based selection is clearer.
- **A `NOTIFICATIONS_ENABLED=false` boolean.** Rejected — a delivery selector
  (`stub` vs `real`) reads better than a disable flag and mirrors the
  local-default / operator-opt-in shape of the sibling legs.
- **In-memory recording adapter with an inspection endpoint.** Deferred —
  log-only was chosen as sufficient; a recording adapter can be added later if a
  test needs to assert on sent notifications.

## Consequences

- The worker no longer attempts real FCM in `Env == local`; a fresh clone's
  notification path completes and logs instead of erroring at `Send`.
- Developers see would-be notifications (loc-keys/args/data/recipient count) in
  logs; real delivery and tap/deep-link behavior are verified only against real
  FCM (operator opt-in) — the accepted fidelity gap.
- `backend/.env.example` / `compose.yaml` notification comments are corrected to
  match reality.

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
  `NewNoop`) already exists; #525 adds a richer log stub and, crucially, selects
  it **explicitly** for `Env == local` (real FCM as an operator opt-in) instead
  of relying on the empty-`FIREBASE_PROJECT_ID` fallback, which the shipped
  non-empty dummy defeats. Flutter needs no change. Design-doc-only;
  implementation stays in #525. Deep-link key mismatch split to #535.
