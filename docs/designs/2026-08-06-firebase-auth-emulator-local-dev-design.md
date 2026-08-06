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

**Safety guard (new code, small).** Add a startup invariant that ties emulator
acceptance to a demo project: if `FIREBASE_AUTH_EMULATOR_HOST` is set, the
process **must fail closed** unless `FIREBASE_PROJECT_ID` begins with `demo-`
(and/or the deploy environment is the local/dev one). This makes "impossible in
prod" a code-enforced invariant rather than deploy-config discipline — the
durable constraint from #524. Production sets neither var, so it is unaffected.

### 2. Flutter — dev-only emulator branch + one-tap test login

- **Connect to the emulator in the dev flavor only.** In `app_startup.dart`,
  after `Firebase.initializeApp()`, gate on `config.environment ==
  AppEnvironment.dev` and call `FirebaseAuth.instance.useAuthEmulator(host,
  port)` with host `10.0.2.2` (Android) / `127.0.0.1` (iOS) — the existing host
  mapping. Staging/production never call it.
- **One-tap dev test login, no credential form.** The login screen shows a
  dev-only section (rendered only when `environment == dev`) with one-tap
  buttons. Each button does a **create-or-sign-in** against the emulator:
  `signInWithEmailAndPassword`, falling back to `createUserWithEmailAndPassword`
  if the user does not exist — with **app-fabricated credentials the user never
  types**. The underlying Firebase provider is `password`; it is surfaced as an
  "Emulator login." This yields a genuine emulator-issued Firebase JWT that
  flows through the existing `firebaseIdTokenProvider` seam, so the rest of the
  app and the backend are unchanged.
  - Provide a few **stable named users** (e.g. `tasker@emulator.local`,
    `referee@emulator.local`) for reproducible multi-account flows (tasker ↔
    referee matching), plus an optional **fresh random user**
    (`dev-<uuid>@emulator.local`) for new-account testing. Because sign-in is
    create-or-sign-in and idempotent, **no Compose-side user seeding is needed**
    — the app self-provisions on tap and survives an emulator reset. The exact
    number/labels of buttons are an implementation detail finalized in the impl
    issue.
- The real Google/Apple buttons stay; against the operator opt-in real-Firebase
  path they work as today.

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
running `firebase emulators:start --only auth --project demo-peppercheck` (a
minimal `firebase.json` enabling only the Auth emulator, port 9099). No user
seeding step (the app self-provisions). Real Firebase is the operator opt-in:
unset `FIREBASE_AUTH_EMULATOR_HOST`, supply real dev configs. In CI the emulator
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
- **Seed users into the emulator via `--import`/bootstrap.** Unnecessary given
  idempotent create-or-sign-in; avoided to keep the stack simpler and reset-safe.

## Consequences

- Backend change is minimal: env vars plus a small fail-closed startup guard;
  the verifier is untouched.
- Flutter change is contained: a dev-gated `useAuthEmulator` call, a dev-only
  login section, and a small email/password create-or-sign-in path in
  `auth_repository.dart` (the only file importing `firebase_auth`).
- The repo gains committed **demo dev-flavor** Firebase configs; `.gitignore` is
  narrowed to un-ignore just those.
- Real Google/Apple sign-in is verified only against the operator opt-in
  real-Firebase path (as today) — the emulator does not exercise native
  federated OAuth.
- Fidelity gaps to verify against real Firebase (opt-in) before shipping:
  actual Google/Apple federated sign-in, token-revocation/disabled-user
  behavior, and real project claims.

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
