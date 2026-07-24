# Phase 2 — Identity & Client Boundary (Design)

> Status: **Design (approved in brainstorming 2026-07-24).**
> Part of the Supabase → Go API + VPS refactor. Program strategy:
> `docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md`
> (see §10 Identity & Authentication and §22 Phase 2). Phase 0 baseline:
> `docs/superpowers/specs/2026-07-22-phase0-baseline.md` (§6(a) Auth
> characterization). Builds directly on the Phase 1 foundation merged into the
> integration branch `refactor/go-api-vps` (commit `13c672a`).
>
> Each phase is its own `spec → plan → implementation` cycle; this document
> covers **Phase 2 only**. The implementation plan is produced separately by the
> writing-plans workflow and is not committed.

---

## 1. Purpose

Phase 2 lays the identity spine of the new architecture and the first real
Flutter ↔ Go client boundary:

- **Firebase Auth (Google + Apple)** replaces Supabase Auth on the
  authenticated-user path.
- The **Go API verifies the Firebase ID token** and resolves it to a stable
  **internal user UUID** via `user_identities(issuer, subject)` (the tables
  already exist from Phase 1). PepperCheck owns the internal ID; the Firebase
  UID is an external key only (strategy D2).
- **`GET /api/v1/me`** returns the resolved internal user.
- Flutter gains **one shared HTTP client** and an **app-level current-user
  contract**; the authentication feature stops using the Supabase SDK.

This is the hardest structural change, done pre-launch while re-login is free
(no production users; internal-test data is disposable — strategy D9).

---

## 2. Decisions locked in brainstorming (2026-07-24)

| # | Decision | Rationale |
|---|----------|-----------|
| P2-D1 | **Transitional narrowing.** Firebase → Go identity becomes the new source of truth. Data features still on Supabase (task/profile/evidence/…, Phases 3–5) are knowingly non-functional against real data on the integration branch until their own phase migrates them. | Matches the strangler reality; avoids a throwaway dual-identity bridge. "Runnable" is scoped to the identity slice (§3). |
| P2-D2 | **Apple Sign-In is included in Phase 2, Google first.** Google is taken end-to-end first (PR P2-5), then Apple is added (PR P2-6). | Strategy: "never defer Sign in with Apple when iOS offers Google." Sequencing keeps each PR runnable. |
| P2-D3 | **RevenueCat is deferred to Phase 5.** Phase 2 only ensures the current-user contract **exposes the internal UUID** so Phase 5 can wire `Purchases.logIn(internalUserId)`. | The app has no RC SDK today (raw IAP). RC entitlement + webhook is money-in (Phase 5). Phase 2 "done" does not include RC. |
| P2-D4 | **Minimal first-sighting provisioning.** On first sighting of an `(issuer, subject)`, provisioning creates **only** `users` + `user_identities` (one transaction). No profile / wallets / notification_settings / username. `GET /api/v1/me` returns the internal user + identity, **no profile**. | Consistent with narrowing and the phase split (profile = Phase 3, point/wallets = Phase 5). The Go-side onboarding step is extended in later phases. |
| P2-D5 | **Firebase token verification uses the Firebase Admin SDK** (`firebase.google.com/go/v4/auth`, `VerifyIDToken`) behind a narrow `platform/auth.TokenVerifier` boundary. | Token verification is security-critical (signature + Google public-key rotation) — do not hand-roll. The Admin SDK is needed later anyway (Phase 6 account deletion: delete Firebase user / revoke tokens). Domain never imports Firebase types. |

The **naming & structure convention** (§4) was also decided in this session and
applies **repo-wide and to future services**, not only to Phase 2.

---

## 3. Execution model — "transitional narrowing"

Per strategy D5 the integration branch must stay buildable and runnable after
every PR. In Phase 2 "runnable" is defined precisely, because switching the
login path to Firebase removes the Supabase session that the not-yet-migrated
data features rely on (Supabase RLS `auth.uid()`):

**After Phase 2 the integration-branch app:**
- ✅ builds and launches (clean clone),
- ✅ signs in with **Google and Apple** via Firebase,
- ✅ resolves the internal user through `GET /api/v1/me`,
- ✅ signs out,
- ⏸ data-heavy features (task/profile/evidence/judgement/point/…) are **not**
  functional against real data until their own phase migrates them to the Go
  API. This is expected and accepted.

`Supabase.initialize(...)` **remains** in app startup because un-migrated data
repositories still reference `Supabase.instance`; those calls are simply
unauthenticated on the integration branch until each feature moves. Only the
**authenticated-user identity path** stops flowing through Supabase in Phase 2.
No dual-identity bridge is built.

PRs land small and feature-sized into `refactor/go-api-vps` (§10). Go work is
verifiable first (curl + a token), then the Flutter client, then Apple.

---

## 4. Naming & structure convention (Option E) — adopted repo-wide

PepperCheck adopts one clean-architecture naming convention across Go and
Flutter so layers correspond by role. It is applied opportunistically as code
is touched (strategy §15), not as a big-bang rename; Phase 2 applies it to the
backend foundation and to the `identity`/`auth` and networking code it creates.

### 4.1 Top-level buckets

| Role | Go | Flutter |
|------|----|---------|
| Entry / composition root | `cmd/<binary>/main.go` | `lib/app/` + `main_*.dart` |
| **`core`** — our own foundation library (things we build/operate; no third-party SaaS) | `internal/core/` | `lib/core/` |
| **`platform`** — adapters to third-party SaaS boundaries (SDK types stop here) | `internal/platform/` | `lib/platform/` |
| Features | `internal/<feature>/` | `lib/features/<feature>/` |

**Classification rule:** *we build/operate it → `core`; a third-party SaaS
boundary → `platform`.* So `config`, `logging`, `httpserver`, `httpclient`,
`database` (our self-hosted Postgres) are `core`; `auth` (Firebase),
`revenuecat`, `stripe`, `r2`, `fcm` are `platform`. `platform/*` may depend on
`core/*`, never the reverse. `platform` reads correctly for external adapters
(e.g. `platform/revenuecat`), where a single `core` bucket would be awkward;
splitting `core`/`platform` keeps every name precise. This is exactly the
strategy §4 rule that "SDK types stop at platform adapters and never reach
domain code."

Go idiom would place `core` packages directly under `internal/` with no
wrapper; we keep the `core`/`platform` wrapper deliberately for cross-language
correspondence. Both wrappers hold **descriptively-named leaf packages**
(`core/config`, `platform/stripe`), so the wrapper directory is organizational
only and does not fall into the `util`/`common` anti-pattern (which is about
meaningless *leaf* package names).

In Flutter, third-party SDK wrappers usually live in the **feature's `data/`
layer** (feature-first idiom), so `lib/platform/` is thin — create a shared
`lib/platform/<service>/` only when an external integration is genuinely
app-wide.

### 4.2 Feature-internal layers

Go groups a feature's roles as **files in one package**; Flutter groups them as
**subfolders**. Names correspond by role:

| Layer | Go (`internal/<f>/`) | Flutter (`lib/features/<f>/`) |
|-------|----------------------|------------------------------|
| domain (models + pure rules) | `domain.go` | `domain/<model>.dart` |
| application (use-case, orchestration, authz, tx boundary) | `service.go` (`type Service`) | `application/<use_case>.dart` |
| data (outbound I/O adapter) | `store.go` (`type Store`) | `data/<model>_repository.dart` + `data/<name>_dto.dart` |
| inbound adapter | `handler.go` (`type Handler`, HTTP) | `ui/<screen>_screen.dart` + `<screen>_view_model.dart` + `widgets/` |

Notes:
- **UI class = `*ViewModel`** (folder `ui/`). Riverpod does not force a
  `Controller` name; the notifier class is named freely
  (`@riverpod class SignInViewModel extends _$SignInViewModel`). This adopts
  the official Flutter MVVM vocabulary.
- **DTOs are separate files** (`data/<name>_dto.dart`, Freezed +
  json_serializable), never inlined into the repository. DTOs mirror the HTTP
  contract, not DB rows (strategy §8); the repository maps DTO ↔ domain; domain
  never imports DTOs.
- Repository **interfaces are optional** — Riverpod provider overrides cover
  most test needs; add an abstract repository only when two implementations
  genuinely coexist (as in the transitional Supabase → API swap).
- The **inbound layer is optional** on both sides: a Go feature invoked only by
  the worker/another service has no `handler.go`; a Flutter feature with no
  route of its own has `ui/widgets/` (largest unit is a widget) and no
  `*_screen.dart`.

### 4.3 Phase 1 reorganization

Phase 1 created `internal/platform/{config,database,httpserver,logging,jobs,
inbox}`. Under this convention those are all **our own foundation** →
`internal/core/{config,database,httpserver,logging,jobs,inbox}`. Phase 2 first
performs this mechanical move (import-path updates; the Go compiler and tests
verify completeness), then adds `internal/platform/auth` (Firebase) as the
first true external-adapter package.

---

## 5. Backend design

### 5.1 Package layout (new/changed)

```
cmd/peppercheck/main.go            # wires TokenVerifier + identity + db into api
internal/
  core/                            # (was internal/platform/*) config, database,
                                   #   httpserver, logging, jobs, inbox, httpclient
    httpserver/                    # + error envelope writer WriteError (added)
  platform/
    auth/                          # Firebase auth boundary (new)
      auth.go                      # Identity, TokenVerifier interface, FakeVerifier
      firebase.go                  # *FirebaseVerifier (firebase.google.com/go/v4)
      middleware.go                # auth middleware + IdentityFrom (uses core/httpserver)
  identity/                        # identity feature (new)
    domain.go                      # User (internal user anchor)
    service.go                     # type Service: ResolveOrProvision
    store.go                       # type Store: Postgres impl over users/user_identities
    handler.go                     # type Handler: GET /api/v1/me
```

### 5.2 Token verification boundary (`platform/auth`)

```go
// Identity is the verified external identity carried out of the boundary.
type Identity struct {
    Issuer        string // e.g. https://securetoken.google.com/<project-id>
    Subject       string // Firebase UID
    Email         string
    EmailVerified bool
}

type TokenVerifier interface {
    Verify(ctx context.Context, rawToken string) (Identity, error)
}
```

- `*FirebaseVerifier` wraps `firebase.google.com/go/v4/auth` and calls
  `VerifyIDToken`. It is constructed from `FIREBASE_PROJECT_ID` (verification
  needs only the project ID; the service-account credential used by later
  phases for user deletion/revocation is added when Phase 6 needs it).
- A `fakeVerifier` returning a fixed `Identity` lets API/service tests run
  without Firebase.
- **Domain and service packages never import Firebase types** — only
  `platform/auth` does.

### 5.3 Error envelope (`core/httpserver`) & auth middleware (`platform/auth`)

- **Error envelope** (`core/httpserver`, strategy §7 — stable machine-readable
  code, never a raw provider error):
  ```json
  { "error": { "code": "unauthenticated", "message": "…", "requestId": "…" } }
  ```
  Codes used in Phase 2: `unauthenticated` (401), `unavailable` (503),
  `internal` (500). The `requestId` echoes `X-Request-Id`. `Recover` also routes
  panics through this envelope (so a panic returns a 500 envelope with a
  `requestId`, not a bare empty 500).
- **Auth middleware** lives in `platform/auth` (cohesive with the verifier; it
  depends on `core/httpserver` for the envelope — `platform` → `core`, the
  allowed direction). It reads `Authorization: Bearer <FirebaseIDToken>`, calls
  `TokenVerifier.Verify`, stores the `Identity` in the request context, and
  **distinguishes failure kinds**: a missing/malformed header or an
  invalid/expired token → `401 unauthenticated`; any other verifier error (e.g.
  a public-key fetch / network failure — not the caller's fault) → `503
  unavailable`, with the original error logged server-side and never returned to
  the client. It composes after the existing RequestID → AccessLog → Recover
  chain.

### 5.4 Identity feature

- `Service.ResolveOrProvision(ctx, issuer, subject string) (User, error)`:
  1. `store.FindByIdentity(issuer, subject)` → return the existing `users.id` if
     present (the common path).
  2. Else, in **one transaction**: insert `users`, then insert
     `user_identities`. `UNIQUE(issuer, subject)` is the final defense; on a
     concurrent first-sighting the unique violation is caught, the transaction
     rolls back (no orphan `users` row), and the row is re-selected (idempotent,
     no duplicate user).
- `Handler` serves `GET /api/v1/me`, authenticated. In Phase 2 the handler
  calls `Service.ResolveOrProvision(ctx, Identity)` (reading the `Identity` the
  middleware placed in context) to resolve/provision, then returns the user.
  Promoting resolution into middleware — so every authenticated request carries
  the internal UUID — is deferred until multiple endpoints need it (a later
  phase). Response:
  ```json
  {
    "user":     { "id": "<internal-uuid>", "status": "active", "createdAt": "…" },
    "identity": { "issuer": "https://securetoken.google.com/<project-id>" }
  }
  ```
  No profile is returned in Phase 2 (profile is Phase 3).
- Feature services authorize by **internal UUID**; store queries are
  user-scoped. Phase 2 has only `/api/v1/me`, which seeds the cross-user
  isolation test pattern reused by later phases.

### 5.5 Config

- Add `FIREBASE_PROJECT_ID` (per environment). Compose injects it into the `api`
  service **fail-closed** (`${FIREBASE_PROJECT_ID:?…}`) so a missing value fails
  loudly rather than booting into silent auth failures; `.env.example` carries a
  dummy so local `make up` still works, staging/production must set the real
  value, and CI passes an explicit dummy.
- **HTTP port — single source of truth.** The port is defined **once** as
  `API_PORT` in the Compose `.env`; the `api` service maps it to `PORT` and Caddy
  reads the same `API_PORT` for its upstream (`reverse_proxy api:{$API_PORT}`).
  The Go config default (`8765`, chosen over the collision-prone `8080`) matches
  it and is only the fallback for standalone (non-Compose) runs. The api is never
  published to the host — Caddy is the only ingress — so smoke tests go through
  Caddy on `:80`.

---

## 6. Flutter design

### 6.1 `core/network` — one shared HTTP client

Today Dio is instantiated ad hoc in `evidence`/`profile` repositories. Phase 2
introduces a single configured client; features must not build their own.
Dio is retained deliberately — its interceptor model is exactly what the
shared-client requirements need, and it is already a dependency (the "stdlib
first, deviate with a concrete reason" bar is met).

`lib/core/network/`:
- **`ApiClient`** wrapping one `Dio`:
  - **base URL** by build env (`AppConfig`/`AppEnvironment`): dev goes **through
    Caddy on `:80`** (the api is not host-published) — `http://10.0.2.2`
    (Android) / `http://127.0.0.1` (iOS sim, via the existing
    `10.0.2.2 → 127.0.0.1` startup rewrite); staging
    `https://staging.peppercheck.dev`; production `https://peppercheck.dev`.
    **Dev cleartext HTTP must be allowed for the dev flavor only:** an Android
    `network_security_config` permitting cleartext to `10.0.2.2`/`localhost`, and
    an iOS ATS exception (`NSAllowsLocalNetworking`). Staging/production are HTTPS
    (no exception). Handled in the Flutter plan (P2-4).
  - **Auth interceptor:** attaches `Authorization: Bearer <token>` on
    authenticated requests, where the token comes from an injected
    `IdTokenProvider` — **not** a direct `firebase_auth` call, so `core/network`
    never imports the Firebase SDK:
    ```dart
    typedef IdTokenProvider = Future<String?> Function({required bool forceRefresh});
    ```
    `features/auth` supplies the Firebase-backed implementation
    (`({required forceRefresh}) async => FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh)`)
    and wires it in at app composition. On `401`, the interceptor calls the
    provider with `forceRefresh: true` and retries **once, for idempotent GET
    only**.
  - **Request-ID interceptor:** propagate/echo `X-Request-Id`.
  - **Timeouts:** bounded connect/receive/send.
  - **No auto-retry of non-idempotent mutations.**
  - **Error mapping:** `{error:{code,message,requestId}}` → a stable
    `ApiException(code, message, requestId, statusCode)`; network/timeout map to
    their own codes. Dio exceptions never reach domain.
- **DTOs** for responses (`MeResponse`) live in the consuming feature's `data/`
  layer and are mapped to domain there.

`firebase_auth` is added as a dependency (currently only `firebase_core` +
`firebase_messaging` are present).

### 6.2 `features/auth` — Firebase adapter + current-user contract

The authentication feature **owns the Firebase SDK**; other features must not
import `firebase_auth` (enforced by a CI architecture import check).

- **`data/` (repository / Firebase adapter):**
  - `signInWithGoogle()`: `GoogleSignIn.authenticate()` → `idToken` →
    `FirebaseAuth.signInWithCredential(GoogleAuthProvider.credential(idToken:))`.
  - `signInWithApple()`: §7 (Apple, PR P2-6).
  - `signOut()`: clear app state → (Phase 5: RC logout) → (Phase 3: FCM
    unregister) → Firebase/Google sign-out. Each leg is attempted independently
    and made idempotent (fixing the current `Future.wait` partial-failure
    ambiguity).
- **Auth state:** the auth-state provider reads `FirebaseAuth.authStateChanges()`
  (replaces the Supabase `onAuthStateChange` stream).
- **App-level current-user contract:** when Firebase-authenticated, the contract
  calls `GET /api/v1/me` via `ApiClient` and exposes an
  `AppUser { internalUserId, … }`. Other features read this contract only.
  The **internal UUID is exposed here** so Phase 5 can wire RevenueCat identify.
- **Remove Supabase from the auth path:** the auth-state provider and repository
  no longer import `supabase_flutter`. `Supabase.initialize(...)` stays in
  startup for un-migrated data features (§3).
- **Rename the feature `authentication` → `auth` (P2-5), per §4.** The current
  dir is `lib/features/authentication/`; P2-5 renames it to `lib/features/auth/`
  and updates imports (mechanical). This is where the convention is applied (§15).
- **Migrate existing auth consumers in the same PR (P2-5) — do not leave them
  dangling.** Several consumers bind Supabase-specific auth types today (the
  `currentUserProvider`'s `User?`, or `authState.value?.session`) and break when
  the contract's type changes; each is updated to the neutral current-user
  contract so the branch still compiles (the data behind them stays
  non-functional until its own phase — narrowing, §3). The chosen approach is
  **update the consumers**, not a compat facade or feature gate. Known consumers:
  - `lib/app/routing/app_router.dart` (`authState.value?.session`) → the
    contract's signed-in state.
  - `…/matching/…/referee_availability_controller.dart` (`session?.user.id`),
    `…/profile/…/current_profile_provider.dart` (`currentUserProvider`),
    `…/home/…/widgets/task_card.dart` (`currentUserProvider?.id`),
    `…/profile/…/avatar_edit_controller.dart` and
    `…/profile/…/username_edit_controller.dart` (`currentUserProvider…user.id`)
    → `AppUser.internalUserId` from the contract.
  - `…/notification/application/fcm_service.dart` (listens to
    `Supabase…onAuthStateChange`) → the new auth-state.
- **FCM token sync is explicitly disabled until Phase 3, not left as a silent
  no-op.** `notification/data/notification_repository.dart` upserts the FCM token
  keyed on the **Supabase** current user, which is null after the auth switch, so
  it would silently no-op. P2-5 gates token registration off (a clear "disabled
  until the notification feature migrates in Phase 3" guard) rather than relying
  on a silent failure. That, plus moving the `fcm_service` listener off
  `onAuthStateChange`, satisfies the "auth path no longer uses the Supabase SDK"
  done criterion (§12).

### 6.3 Post-login navigation

The app enters past login only after **both** Firebase authentication **and**
`GET /api/v1/me` resolution succeed. If `/me` fails after a successful Firebase
sign-in, the app shows a retry + sign-out affordance rather than a "signed in
to Firebase but no internal user" limbo. Provisioning is idempotent, so retry is
safe.

---

## 7. Apple Sign-In & operator/infra checklist (PR P2-6)

**Flutter code:**
- Add `sign_in_with_apple`. Generate a secure nonce (random + SHA-256) →
  `OAuthProvider('apple').credential(idToken:, rawNonce:)` →
  `signInWithCredential`.
- Handle `account-exists-with-different-credential` (Workspace/custom domains
  that Firebase does not auto-link): catch → re-authenticate with the existing
  provider → `linkWithCredential`. Handle both the auto-link and explicit-link
  paths. The app never merges users on an email-string match.
- **Apple Hide My Email:** relay addresses differ from the real email; such
  accounts stay separate unless explicitly linked, and revealing the real email
  later does not retroactively merge.

**Operator / infrastructure runbook** (per environment — dev / staging /
production Firebase projects; add a Pending entry to the release-checklist skill
when P2-5 lands, and complete it before that environment's release):
1. **Firebase — Google provider:** enable Google sign-in in each project's
   Authentication → Sign-in method (Google currently flows through Supabase, so
   Firebase Auth Google enablement is net-new); confirm the OAuth consent screen.
2. **Firebase — one-account-per-email:** in Authentication → Settings, confirm
   the account-linking setting ("one account per email address") matches the
   design (auto-link trusted verified providers), so Google/Apple with the same
   verified email converge to one Firebase UID.
3. **Android SHA keys:** register the SHA-1 **and** SHA-256 of the signing key
   for **each flavor** (dev debug keystore, staging, production) in the matching
   Firebase project — Google sign-in fails without them.
4. **Firebase — Apple provider:** enable Apple in each project and register the
   Services ID + Sign in with Apple key.
5. **Apple Developer:** add the "Sign in with Apple" capability to each App ID;
   create the Services ID and the Sign in with Apple key used in step 4.
6. **Xcode:** add the Sign in with Apple capability to the Runner target per
   flavor scheme.
7. **`FIREBASE_PROJECT_ID` injection:** set the real per-env project ID for the
   deployed api (staging/production), replacing the dummy local default (§5.5).
8. **E2E smoke (per platform, real device):** verify Google sign-in and Apple
   sign-in for the **same verified email** resolve to the **same internal user**
   (one Firebase UID → one `/api/v1/me` `user.id`), and that an Apple
   Hide-My-Email relay stays a **separate** account.

---

## 8. Testing & CI

**Go unit:** `identity.Service` — known identity → same UUID; first sighting →
`users` + `user_identities` created atomically; concurrent first-sighting →
unique violation re-resolves with no duplicate. `TokenVerifier` via the fake.

**Go API integration** (HTTP + real Postgres + fake `TokenVerifier`):
- missing / invalid / expired token → `401 unauthenticated`; a non-token
  verifier failure (infra, e.g. public-key fetch) → `503 unavailable`;
- valid token, first call → user created, `/api/v1/me` returns the internal
  UUID + identity;
- valid token, second call → same UUID (no duplicate);
- **user isolation:** a token for user B never returns user A's user (seed of
  the authz-isolation pattern);
- error-envelope contract: stable `code` + non-empty `requestId` for `401
  unauthenticated` and `503 unavailable`, asserted through the real RequestID
  middleware chain.

**Schema / DB integration:** the constraint behavior — `UNIQUE(issuer, subject)`,
`users` ↔ `user_identities` FK cascade, and no-orphan-`users` on rollback — is
covered by the Go store integration tests (CI-enforced via `make test`), plus a
transactional **assert-SQL** file `backend/db/tests/test_identity_constraints.sql`
in the repo's existing `db/tests/` style. `db/tests/*.sql` **is** run in CI
(`ci-backend.yml` already runs `test_role_separation.sql`); Phase 2 generalizes
that step to a `db/tests/*.sql` loop so the new file runs automatically. No pgTAP
is introduced — the strategy's "pgTAP" wording (§24) is aspirational; this uses
assert-SQL. (Migrations applying cleanly to an empty DB is already checked by
Phase 1 CI.)

**Flutter:**
- `core/network` `ApiClient` (fake HTTP): auth interceptor attaches the header;
  envelope → `ApiException`; no auto-retry on POST; request-id propagation.
- `features/auth`: auth-state transitions; the current-user contract resolves
  the internal UUID from a fake `/me`; sign-out clears state (fake Firebase
  current-user + fake repository).

**CI gates:** Go — gofmt, `go vet`, unit, Postgres integration, race, Atlas
fmt/lint, apply-to-empty-DB, schema-drift, image build. Flutter — dart format,
`flutter analyze`, tests, **architecture import checks** (`firebase_auth` only
in `features/auth`; Dio construction only in `core/network`), flavored debug
build (`lib/main_dev.dart`). Per project convention, each Flutter PR runs
`flutter build` only; a single emulator pass runs at the end of Phase 2 on the
integration branch.

---

## 9. Error handling & edge cases

Derived from the Phase 0 baseline §6(a) auth characterization:

- **`account-exists-with-different-credential`** → re-auth + `linkWithCredential`
  (§7), never a silent second account.
- **Partial sign-out failure** → each leg independent and idempotent; do not
  inherit the current `Future.wait` ambiguity.
- **Apple Hide My Email churn** → no retroactive merge.
- **`/api/v1/me` failure after Firebase sign-in** → retry + sign-out, no limbo
  (§6.3); provisioning is idempotent.
- **Provisioning atomicity** → `users` + `user_identities` in one transaction;
  concurrent first-sighting resolves via the unique constraint.
- **Username generation is deferred** — Phase 2 provisioning creates **no**
  username/profile. The current 5-attempt bounded-retry username generation
  (today in `handle_new_user`) is carried into **Phase 3 (profile)**; the Go
  port must keep an equivalent bound rather than an unbounded loop. Recorded
  here so it is not lost.
- **Token failures** → expired → `401` (client force-refreshes and retries an
  idempotent GET once); invalid signature/aud/iss → `401`, no retry.

---

## 10. PR breakdown

Small, feature-sized PRs into `refactor/go-api-vps`; the branch builds after
each (§3). Go first (verifiable via curl + token), then Flutter, then Apple.

| PR | Layer | Content |
|----|-------|---------|
| P2-1 | Go | Structure reorg: `internal/platform/*` → `internal/core/*` (Phase 1 packages); adopt the §4 convention. Mechanical, compiler + tests verify. |
| P2-2 | Go | `platform/auth` `TokenVerifier` (Firebase impl + fake); auth middleware; error envelope; `FIREBASE_PROJECT_ID`; local port `8765`. |
| P2-3 | Go | `identity` feature (`domain`/`service`/`store`/`handler`); `GET /api/v1/me`; authz-isolation + API integration + db/tests assert-SQL constraint tests. |
| P2-4 | Flutter | `core/network` `ApiClient` (base URL, token/request-id interceptors, timeouts, error mapping); add `firebase_auth`; base-URL config. |
| P2-5 | Flutter | `features/auth` Firebase adapter (**Google**); app-level current-user contract exposing the internal UUID; remove Supabase from the auth path → **Google end-to-end**. |
| P2-6 | Flutter + infra | Apple Sign-In (`sign_in_with_apple`, nonce, `linkWithCredential`); operator/infra checklist (§7) → **Apple end-to-end**. Single emulator verification pass. |

---

## 11. Out of scope (deferred to later phases)

- Profile / username / wallets / notification_settings / trial-point
  provisioning → Phase 3 (profile) and Phase 5 (point).
- RevenueCat SDK + identify + entitlement + webhook → Phase 5.
- Any other feature's Supabase → Go migration (task, evidence, judgement,
  payout, notification, report, account) → their phases.
- Go web (html/template) pages, provider-neutral account-deletion → Phase 3.
- Retiring RLS / removing the Supabase runtime SDK → final cutover (Phase 7).

---

## 12. Done criteria (Phase 2)

- [ ] A clean clone builds and runs; sign-in (Google **and** Apple), `/api/v1/me`,
      and sign-out work on the integration branch.
- [ ] Both providers create/restore the **same internal user** (same verified
      email → one account via Firebase linking; Apple Hide-My-Email stays
      separate unless explicitly linked); no duplicate users.
- [ ] The Go API verifies the Firebase ID token and resolves it to the internal
      UUID; domain/service packages import no Firebase types.
- [ ] User-isolation authz test passes (a token for one user cannot read
      another's user).
- [ ] One shared Flutter HTTP client; `features/auth` owns the Firebase SDK; the
      app-level current-user contract exposes the internal UUID; no `firebase_auth`
      import outside `features/auth`.
- [ ] The authenticated-user path no longer uses the Supabase SDK
      (`Supabase.initialize` may remain for un-migrated data features).
- [ ] Backend structure follows the §4 convention (`core`/`platform`/features).
- [ ] CI gates (§8) pass.

**Not** Phase 2 criteria: profile/wallet provisioning; RevenueCat; other
features' migration; RLS retirement; Supabase SDK removal.
