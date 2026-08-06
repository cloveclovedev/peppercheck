# Firebase Auth Emulator — Zero-Account Local Sign-In

**Date:** 2026-08-06
**Issues:** #524 (design), #529 (implementation), #522 (parent — OSS local dev profile), #523 (sibling — Garage object storage)
**Status:** Approved

## Context

Signing in locally currently requires a **real Firebase project**. The Flutter
app wires Google (`google_sign_in` + `signInWithCredential`) and Apple
(`signInWithProvider`) in `peppercheck_flutter/lib/features/auth/data/auth_repository.dart`,
initializes Firebase from native per-flavor config files
(`Firebase.initializeApp()` with no `options`, relying on `google-services.json`
/ `GoogleService-Info.plist`), and the Go API verifies the resulting ID token
with the Firebase Admin SDK. An OSS contributor without operator-provisioned
Firebase config and OAuth clients therefore cannot sign in at all — the
zero-account goal of the OSS local dev profile (#522) is blocked at the front
door, the same way object storage was before Garage (#523).

The Firebase Local Emulator Suite provides an Auth emulator that runs against a
`demo-` project with **no account**, and issues **unsigned** ID tokens that are
accepted only when a server opts in via `FIREBASE_AUTH_EMULATOR_HOST` (real
verifiers reject them).

### Grounding: how auth is wired today

- **Backend verifies with the Firebase Admin Go SDK v4**, not manual JWKS —
  `backend/internal/platform/auth/firebase.go` calls `client.VerifyIDToken`,
  built via `firebase.NewApp(&firebase.Config{ProjectID: projectID},
  option.WithoutAuthentication())`. Project ID comes from `FIREBASE_PROJECT_ID`
  (`core/config/config.go`). No service account is needed for verification.
- **The Admin SDK natively honors `FIREBASE_AUTH_EMULATOR_HOST`.** In
  `firebase-admin-go`, `NewClient` sets `isEmulator = true` when the env var is
  present, and `tokenVerifier.VerifyToken(ctx, token, isEmulator)` **skips
  signature verification** when `isEmulator` is true while still validating
  `iss`, `aud`, `sub`, `exp`, `iat`. So emulator tokens for `demo-peppercheck`
  are accepted with **no verifier code change**.
- **Flutter has no emulator wiring today** — no `useAuthEmulator`, no
  `firebase_options.dart`; flavor selection is native (`main_dev.dart` →
  `AppConfig.dev`). The ID token reaches `core/network` through the
  `firebaseIdTokenProvider` seam (`features/auth/application/auth_state.dart`),
  and the API host already maps Android `10.0.2.2` / iOS `127.0.0.1`
  (`app/config/app_environment.dart`, `app/app_startup.dart`).
- **Native Google/Apple sign-in does not work against the emulator** on a device
  or simulator (the emulator serves a mock IdP page, not native OAuth).

## Goals

- A clean `git clone` can sign in and exercise authenticated flows **with zero
  external accounts and zero flags** (no Firebase project, no OAuth clients).
- Reuse the real production auth code path (Admin SDK verification, the ID-token
  seam) rather than a bypass; only the token issuer becomes the emulator.
- Keep real Firebase as an **operator opt-in** (mirrors Garage / BWS).
- Make emulator acceptance **impossible to enable in staging/production**.

## Non-goals

- Native federated Google/Apple against the emulator (unsupported; real Google/
  Apple remain for the operator opt-in path).
- Push / FCM locally — separate leg of #522 (#525).
- The worker (no inbound auth surface).
- Changing production auth behavior in any way.

## Decision

### 1. Backend — env-only, no verifier code change

Locally, set two env vars on the api container (Compose): `FIREBASE_PROJECT_ID=demo-peppercheck`
and `FIREBASE_AUTH_EMULATOR_HOST=<auth-emulator-host>:9099`. The Admin SDK then
accepts emulator-issued tokens (signature skipped; `iss` =
`https://securetoken.google.com/demo-peppercheck`, `aud` = `demo-peppercheck`,
`exp` still enforced). `option.WithoutAuthentication()` is already in place, so
no service account is involved.

**Safety guard (new code, small).** Add a startup invariant: if
`FIREBASE_AUTH_EMULATOR_HOST` is set, the process **must fail closed** unless
**both** `Config.Env == "local"` **and** `FIREBASE_PROJECT_ID` begins with
`demo-`. `Config.Env` already distinguishes `local | staging | production`
(`core/config/config.go`, from `APP_ENV`). Both conditions are required, not
"and/or": a demo project ID alone is not sufficient, because a staging/production
deploy accidentally configured with `FIREBASE_AUTH_EMULATOR_HOST` **and** a
`demo-*` project would otherwise start with signature verification skipped and
accept forged unsigned tokens whose claims match the demo project. Requiring
`Env == local` makes emulator acceptance impossible outside local development —
a code-enforced invariant, not deploy-config discipline. Production sets neither
var (and is not `local`), so it is unaffected.

**Launcher must select the demo project in emulator mode.** The canonical
launcher `scripts/dev-run.sh` currently defaults `FIREBASE_PROJECT="peppercheck-dev"`
and `start_backend` exports it as `FIREBASE_PROJECT_ID`. If it also sets
`FIREBASE_AUTH_EMULATOR_HOST` while keeping that default, the new guard would
**abort API startup** (`peppercheck-dev` is not `demo-`). So the launcher's
default emulator (zero-flag) path must set `FIREBASE_PROJECT=demo-peppercheck`
**and** `FIREBASE_AUTH_EMULATOR_HOST`; the operator opt-in path (`--firebase-project
<operator>`) must instead select the real project **and** leave the emulator host
unset and the client switch off. `#529` updates `dev-run.sh` accordingly.

### 2. Flutter — dev-only emulator branch + one-tap test login

- **Gate emulator wiring on an explicit switch, not the flavor alone.** The
  operator opt-in real-Firebase path *also runs the dev flavor*, so gating on
  `environment == dev` alone would keep calling `useAuthEmulator` even after the
  operator supplies real configs — leaving auth redirected to localhost and the
  Google/Apple buttons unable to reach real Firebase. Introduce an explicit
  client switch (e.g. `--dart-define=USE_AUTH_EMULATOR`, or a dev-env config
  field) that **defaults ON for zero-flag dev** and can be set OFF for the
  operator opt-in path. In `app_startup.dart`, after `Firebase.initializeApp()`,
  call `FirebaseAuth.instance.useAuthEmulator(host, port)` only when the switch
  is on (host `10.0.2.2` Android / `127.0.0.1` iOS — the existing mapping).
  Staging/production force it off. The dev login UI below uses the **same
  switch**, so turning the emulator off restores the plain Google/Apple screen.
- **One-tap dev test login, no credential form.** When the emulator switch is on,
  the login screen shows a dev-only section with one-tap buttons (app-fabricated
  credentials the user never types; the underlying Firebase provider is
  `password`, surfaced as an "Emulator login"). The resulting emulator-issued
  Firebase JWT flows through the existing `firebaseIdTokenProvider` seam, so the
  rest of the app and the backend are unchanged. Two distinct button behaviors:
  - **Named users are sign-in-only** (e.g. `tasker@emulator.local`,
    `referee@emulator.local`): `signInWithEmailAndPassword` with **no create
    fallback**. If the fixed-UID seed is missing (bootstrap/import not done, or
    Auth state cleared while the API DB persists), the button **fails visibly**
    rather than creating the email with an SDK-assigned UID — a client-created
    user would take a random UID that the later fixed-UID seed cannot repair,
    silently mapping the button to a *new* backend identity. Creation is reserved
    for the random action below.
  - **The random user** (`dev-<uuid>@emulator.local`) is the only button that
    `createUserWithEmailAndPassword`; it is ephemeral by design (no stable
    identity needed).
  - Stable named identities therefore depend on **fixed-UID seeding** (§4): the
    emulator is seeded with fixed-UID named users (or its auth state persisted),
    so a named button always maps to the same `(iss, sub)` and backend identity
    across restarts. Exact button count/labels are finalized in the impl issue.
- The real Google/Apple buttons stay; with the emulator switch off (operator
  opt-in real-Firebase path) they work as today.

### 3. Native dev Firebase config — commit a demo config

`Firebase.initializeApp()` needs a native config file to initialize even when
all auth is redirected to the emulator. Commit a **hand-authored demo config for
the dev flavor** — `google-services.json` (Android) / `GoogleService-Info.plist`
(iOS) for project `demo-peppercheck`, with the dev flavor's applicationId
(`…​.dev` suffix) / bundle id. These carry only **public identifiers**; a
Firebase config's API key is not a secret (Google states this explicitly), and
here the project is a non-existent demo whose fabricated key never reaches real
Google because auth is redirected to the emulator. Un-ignore **only the dev
flavor** files in `.gitignore`; staging/production configs stay ignored. FCM
registration against the demo config will no-op/fail gracefully locally
(expected; real push is #525).

### 4. Compose — run the Auth emulator as a zero-flag default

Add an auth-emulator service to the local stack: a `firebase-tools` container
running `firebase emulators:start --only auth --project demo-peppercheck`. The
`firebase.json` must set the Auth emulator's **`host` to `0.0.0.0`** (not just
`port: 9099`): the Firebase CLI binds to `127.0.0.1` by default, which inside a
dedicated container is unreachable from the api container or the Flutter
emulator, so every token request/verification would fail. Bind `0.0.0.0` and
control exposure through Compose port mapping.

```json
{ "emulators": { "auth": { "host": "0.0.0.0", "port": 9099 } } }
```

**Allocate the host port per worktree.** `9099` above is the container-internal
port; the **host** port must be worktree-allocated, not fixed. The parallel-worktree
launcher `scripts/worktree/dev.sh` already allocates and persists unique host
ports per worktree (`CADDY_HTTP_PORT`, `CADDY_HTTPS_PORT`, `POSTGRES_HOST_PORT`)
and passes the app one via `--dart-define=DEV_API_PORT`. Add an allocated
`AUTH_EMULATOR_HOST_PORT` to the same worktree state / Compose mapping, and pass
the matching port to Flutter (alongside the emulator switch) — otherwise a second
worktree either fails the port bind or connects its app to the first worktree's
Auth emulator. The single-stack `dev-run.sh` path can keep a fixed default.

**Seed fixed-UID named users so stable identities survive an emulator restart.**
The API database (Compose Postgres volume) persists across restarts and keys
internal users by `(iss, sub)` — but if the Auth emulator restarts and its users
are gone, a client `createUserWithEmailAndPassword` for `tasker@emulator.local`
gets a **new** Firebase UID (the client API cannot set one), so the backend
provisions a *new* internal user and the old tasks/matches become unreachable.
Avoid this by giving the named users **deterministic UIDs**, via either:
(a) a bootstrap step that creates them through the emulator's **admin REST API**
(`accounts` endpoint accepts an explicit `localId`), or (b) `--import` of a
committed auth-export dir plus `--export-on-exit` to persist. Either keeps
`(iss, sub)` stable so named buttons always resolve to the same backend identity.
The random user needs no seeding (ephemeral by design). If instead the operator
resets the Auth emulator without seeding, they must also reset the API database
to stay consistent.

Real Firebase is the operator opt-in: unset `FIREBASE_AUTH_EMULATOR_HOST`, set
the client emulator switch off, and supply real dev configs. In CI the emulator
runs the same way for any auth-dependent integration test.

## Alternatives considered

- **Backend auth-bypass token (dev-only "skip verification").** Rejected — a
  verification backdoor is a real security hazard if it ever leaks to a
  non-dev build. The emulator keeps the real verification path (Admin SDK)
  intact; only the issuer changes, and the safety guard forbids it outside a
  demo project.
- **Email/password entry form.** Rejected — adds a credential form the product
  does not otherwise have (Google/Apple only). One-tap create-or-sign-in needs
  no form.
- **Anonymous sign-in.** Simplest, but gives no stable identity/email, so
  multi-account matching (tasker ↔ referee) can't be reproduced. Not chosen as
  the primary mechanism.
- **Emulator mock IdP web page.** Closest to the real federated flow, but
  awkward inside a mobile webview and needs no benefit over one-tap here.
- **Template + generation script for the native config.** Rejected in favor of
  committing the demo config, for a true zero-flag first run (chosen per the
  parent profile's zero-flag default).
- **Rely on idempotent create-or-sign-in with no seeding.** Rejected — it is
  *not* reset-safe: after an Auth-emulator restart, client `createUser` re-mints
  a new UID for the same email while the API DB (persisted) still keys the old
  `(iss, sub)`, so a "stable" named user silently becomes a different backend
  identity. Fixed-UID seeding (or auth-state persistence) is required instead
  (§4).

## Consequences

- Backend change is minimal: env vars plus a small fail-closed startup guard
  requiring **both** `Env == local` and a `demo-` project; the verifier is
  untouched.
- Flutter change is contained: an explicit-switch-gated `useAuthEmulator` call,
  a dev-only login section behind the same switch, and a small email/password
  path in `auth_repository.dart` (the only file importing `firebase_auth`) —
  sign-in-only for named users, create only for the random user.
- The launchers change: `dev-run.sh`'s emulator (default) path selects
  `FIREBASE_PROJECT=demo-peppercheck` and sets the emulator host (else the guard
  aborts startup); `--firebase-project <operator>` selects real Firebase with the
  host unset. `scripts/worktree/dev.sh` allocates an `AUTH_EMULATOR_HOST_PORT`
  per worktree and passes it to Flutter, like its existing Caddy/Postgres ports.
- The client needs a `USE_AUTH_EMULATOR`-style switch (default on for dev) so
  the operator opt-in real-Firebase path can turn the emulator off; without it,
  dev-flavor auth would stay pinned to localhost.
- The Compose stack seeds **fixed-UID** named emulator users (admin REST
  `localId`, or `--import`/`--export-on-exit`) so stable identities align with
  persisted backend rows across restarts.
- The repo gains committed **demo dev-flavor** Firebase configs; `.gitignore` is
  narrowed to un-ignore just those.
- Real Google/Apple sign-in is verified only against the operator opt-in
  real-Firebase path (as today) — the emulator does not exercise native
  federated OAuth.
- Fidelity gaps to verify against real Firebase (opt-in) before shipping:
  actual Google/Apple federated sign-in, token-revocation/disabled-user
  behavior, and real project claims.

## Dependencies / prerequisites

This feature is **necessary but not sufficient** for a fully account-free clone.
On the current `refactor/go-api-vps` branch, the app fails to start **before**
Firebase Auth initializes: `pubspec.yaml` declares `assets/env/.env.dev` as a
required asset (and `.env.*` is gitignored, so it is absent on a fresh clone),
and `app_startup.dart`'s `_initSdk` **throws unless `SUPABASE_URL` /
`SUPABASE_ANON_KEY` are set** and then calls `Supabase.initialize`. Supabase is
still the backend for many not-yet-migrated features (matching, task, evidence,
judgement, payment, report, account), so it cannot simply be dropped mid-refactor.

Therefore the zero-account goal has a **shared prerequisite**, owned by the
parent profile (#522), not by this issue: a committed or generated **account-free
dev env** (`assets/env/.env.dev`) whose `SUPABASE_*` values point at the **local
Supabase stack** (`supabase start`, no external account — the analog of Garage /
the Auth emulator), plus eventual removal of the hard Supabase requirement as the
refactor completes. This same gap also blocks Garage avatar display from a fresh
clone (#523), which is why it belongs to the profile, not to auth. This design
assumes that prerequisite is in place; it is tracked in **#532** and linked from
#529.

## Deferred / related work

- #523 Garage (storage) and #525 FCM stub — the other legs of the zero-account
  local profile (#522), following the same zero-flag-default / operator-opt-in
  pattern.
- #436 dev-only client mock layer — complementary: client-side simulated flows
  for services with no local emulator (Stripe/IAP purchase, payout). This design
  deliberately prefers the real local emulator over a client bypass for auth.
- #477 program parent — the Phase 2 identity boundary this builds on.

## References

- Connect to the Auth emulator: https://firebase.google.com/docs/emulator-suite/connect_auth
- Verify ID tokens: https://firebase.google.com/docs/auth/admin/verify-id-tokens
- `firebase-admin-go` emulator handling: `auth/auth.go` (`FIREBASE_AUTH_EMULATOR_HOST` → `isEmulator`), `auth/token_verifier.go` (`VerifyToken(..., isEmulator)` skips signature when true)
- `backend/internal/platform/auth/firebase.go`, `backend/internal/core/config/config.go`
- `peppercheck_flutter/lib/features/auth/data/auth_repository.dart`, `lib/app/app_startup.dart`, `lib/app/config/app_environment.dart`

## Decision log

- **2026-08-06** — Initial design. Backend accepts emulator tokens via the Admin
  SDK's native `FIREBASE_AUTH_EMULATOR_HOST` support (no verifier change) plus a
  fail-closed guard tying emulator mode to a `demo-` project. Flutter connects
  `useAuthEmulator` in the dev flavor and adds a one-tap, no-form
  create-or-sign-in "Emulator login" (stable named users + optional random),
  reusing the existing ID-token seam. A hand-authored demo dev-flavor Firebase
  config is committed; the Auth emulator runs as a zero-flag Compose default with
  real Firebase as the operator opt-in. Design-doc-only; implementation tracked
  in #529.
- **2026-08-06** — First Codex round on PR #530, three fixes. (1, P1) The guard
  now requires **both** `Env == local` **and** a `demo-` project (not "and/or"):
  a demo project alone would let a misconfigured staging/prod deploy start with
  signatures skipped and accept forged tokens. (2, P2) Client emulator wiring is
  gated on an **explicit switch** (default on for dev), not the flavor alone —
  otherwise the operator opt-in path still runs the dev flavor and stays pinned
  to localhost, so real Google/Apple never work. (3, P2) Dropped the "no seeding,
  reset-safe" claim: client `createUser` can't set a UID, so after an Auth-emulator
  restart a named user re-mints a new UID while the persisted API DB keys the old
  `(iss, sub)`. Named users now need **fixed-UID seeding** (admin REST `localId`)
  or auth-state persistence.
- **2026-08-06** — Second Codex round on PR #530 (P1): the Firebase CLI binds the
  emulator to `127.0.0.1` by default, unreachable from the api container / Flutter
  emulator inside a dedicated container. The `firebase.json` must bind the Auth
  emulator `host` to `0.0.0.0`, with exposure controlled via Compose.
- **2026-08-06** — Third Codex round on PR #530 (P1): the clean-clone path fails
  *before* Firebase Auth initializes — `pubspec.yaml` requires the gitignored
  `assets/env/.env.dev`, and `_initSdk` throws without `SUPABASE_URL` /
  `SUPABASE_ANON_KEY`. Added a Dependencies section: the zero-account goal has a
  shared prerequisite (account-free dev env pointing at the local Supabase stack)
  owned by the parent profile #522, also blocking Garage (#523). This design is
  necessary but not sufficient on its own. Filed as #532.
- **2026-08-06** — Fourth Codex round on PR #530, all grounded in the real
  launchers. (1, P1) `scripts/dev-run.sh` defaults `FIREBASE_PROJECT=peppercheck-dev`;
  once the emulator host is set, the guard would abort startup, so the launcher's
  emulator path must select `demo-peppercheck` and the real path selects the
  operator project with the host unset. (2, P2) Named-user buttons are now
  **sign-in-only** and fail visibly when their fixed-UID seed is missing (only the
  random button creates), so a mistimed tap can't mint an unrepairable
  SDK-assigned UID. (3, P2) The Auth emulator **host port is worktree-allocated**
  (`AUTH_EMULATOR_HOST_PORT`, like `scripts/worktree/dev.sh`'s Caddy/Postgres
  ports) and passed to Flutter, so parallel worktrees don't collide or cross-wire.
