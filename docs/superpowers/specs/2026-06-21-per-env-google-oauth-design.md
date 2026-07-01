# Per-Environment Google Sign-In (dev + production) — Design

Issue: #427 (part of the multi-environment roadmap #418)
Roadmap tasks: 1.9, 1.10, 1.11 (dev), 1.13
Status: design approved, ready for implementation planning

## Background — where this sits in the multi-environment split

The multi-environment roadmap (#418) splits the app into three fully isolated
environments — **dev**, **staging**, **production** — each with its own bundle
ID (`.dev` / `.staging` / none), Firebase project, Supabase project, signing,
OAuth clients, and store presence. The point is to develop and test against a
dev backend without ever touching production users or data.

Earlier phases already built most of the plumbing:

- Per-flavor bundle IDs and Xcode schemes/xcconfig.
- Per-env Firebase projects and apps, with `google-services.json` /
  `GoogleService-Info-<Flavor>.plist` downloaded and injected per flavor
  (`register-firebase-apps.sh` + the iOS "Inject Firebase GoogleService-Info"
  build phase).
- Per-env Supabase projects and tag-based CI deploys (`deploy-beta.yml`,
  `deploy-production.yml`).
- A single APNs Auth Key uploaded to all three Firebase projects (#425).

**What was still missing: authentication.** Every flavor shared the *production*
Google OAuth client (`bootstrap-ios-secrets.sh` wrote the prod `GID_CLIENT_ID`
into all three iOS xcconfigs), so signing into the dev or staging app was broken
by design. Authentication is the gate to everything else — you cannot exercise
the dev backend end to end until you can log into it.

**#427 delivers the auth slice for the dev environment (plus a production
regression pass).** It gives dev its own OAuth clients and teaches the dev
Supabase project to accept them, so a developer can finally sign into the dev
app against the dev backend. Because a real push-notification test needs an FCM
token from a signed-in user, #427 also closes out the end-to-end push test that
#425 deferred: sign in on dev → receive a push from the dev `send-notification`.
After #427, the dev environment is auth- and push-complete.

Production is touched only additively (it already works). **Staging is out of
scope and moves to #429**, because staging's Android OAuth client needs the Play
App Signing fingerprint, which does not exist until the staging Play app is
created in a later phase. The setup script is built env-parameterized so #429
reuses it verbatim.

## The core technical finding (corrects the roadmap's original premise)

The roadmap originally assumed we would "unify on a Web client" by injecting it
as `serverClientId` so every idToken carried `aud` = Web client, letting each
Supabase project trust a single client ID. **That premise is wrong**, verified
against the plugin sources and Supabase's official guide:

- **Android** (`google_sign_in_android` 7.2.6,
  `lib/google_sign_in_android.dart:41`): with no `serverClientId` argument it
  falls back to `getGoogleServicesJsonServerClientId()`, i.e. the
  `default_web_client_id` generated from `google-services.json`. The idToken
  `aud` is the **Web client**. (This is why production works today with a bare
  `GoogleSignIn.instance.initialize()`.)
- **iOS** (`google_sign_in_ios` 6.2.4, `FLTGoogleSignInPlugin.m`): the client is
  read from the bundled `GoogleService-Info.plist` `CLIENT_ID` (the per-flavor
  plist is injected by an Xcode build phase). The idToken `aud` is the **iOS
  client**. `serverClientID` would only add a `serverAuthCode`; Supabase's native
  `signInWithIdToken` flow does not need it.
- **Supabase** (official Flutter guide): the Google provider's *Client IDs*
  field must list **both** the Web and iOS client IDs, comma-separated, Web
  first. GoTrue validates the idToken `aud` against that list. Verified via
  Context7 that both the hosted `external_google_client_id` and local
  `config.toml` `client_id` accept a comma-separated list.

**Consequences:**

- **No app code change.** `app_startup.dart` keeps
  `GoogleSignIn.instance.initialize()` with no arguments. No `serverClientId`,
  no new `.env` key.
- The per-environment work is entirely in the *config files the app already
  receives per flavor* (`google-services.json`, `GoogleService-Info.plist`) plus
  each Supabase project's provider settings.
- The Web client **secret** is still required — not for mobile sign-in, but
  because the webapp (`peppercheck-webapp/.../login/page.tsx`) uses
  `supabase.auth.signInWithOAuth({ provider: 'google' })`, the browser
  authorization-code flow, on the same Supabase project.

## Scope

| Environment | In #427? | What happens |
| --- | --- | --- |
| dev | ✅ | New OAuth clients (Android via SHA, iOS client), local Supabase provider config, dev FCM service account wiring, full local verification (sign-in + push e2e). |
| production | ✅ (additive/regression) | Reuse existing clients; ensure the prod Supabase *Client IDs* authorizes both the prod Web and prod iOS client; regression-check sign-in. No app change. |
| staging | ❌ → #429 | Deferred; the script is reused once the staging Play app (and its Play App Signing SHA) exists. |

## Design

### 1. App code — no change

`peppercheck_flutter/lib/app/app_startup.dart` keeps
`GoogleSignIn.instance.initialize()` (no arguments). Rationale in "core technical
finding" above. This makes production trivially backward compatible.

### 2. `scripts/setup/setup-google-signin.sh <env>`

Env-parameterized (`dev | staging | production`), idempotent, additive. Renamed
from the roadmap's `create-oauth-clients.sh` because there is no API that
*creates* consumer OAuth clients — creation is Firebase-CLI-triggered plus a
couple of Console-manual steps. Reuses `register-firebase-apps.sh` conventions
(resolve `projectId` from the Firebase display name; `suffix` / `cap_env`).

Steps:

1. **Compute signing fingerprint.** dev → SHA-1/256 of
   `~/.android/debug.keystore` (alias `androiddebugkey`, storepass `android`) via
   `keytool`. staging/production → Play App Signing SHA from
   `~/.config/peppercheck-secrets/` or a printed Play Console instruction (unused
   in #427; used by #429).
2. **Register the SHA idempotently.** Check `firebase apps:android:sha:list`,
   then `firebase apps:android:sha:create <androidAppId> <sha>`. This
   auto-creates the Android OAuth client and the paired Web auto-client.
   (package-name × SHA must be unique across projects — fine here because
   dev/staging/prod use distinct bundle IDs, so the same debug SHA can register
   to all three.)
3. **Re-download configs** via `firebase apps:sdkconfig`:
   `android/app/src/<flavor>/google-services.json` and
   `ios/Runner/Firebase/GoogleService-Info-<Cap>.plist`.
4. **Print manual checkpoints** (see "spike" below): create the iOS OAuth client;
   copy the Web client secret from the Console; confirm the OAuth consent screen.
5. **Reflect the iOS redirect scheme.** Extract `REVERSED_CLIENT_ID` from
   `GoogleService-Info-<Cap>.plist` and write `GID_REVERSED_CLIENT_ID` (and, for
   compatibility, `GID_CLIENT_ID`) into
   `ios/Flutter/Secrets/<Cap>.secrets.xcconfig`. This replaces
   `bootstrap-ios-secrets.sh`'s "write the prod GID into all three flavors".
   (`GID_CLIENT_ID` is vestigial now that the plugin reads the iOS client from
   the plist, but `GID_REVERSED_CLIENT_ID` is still needed for the
   `CFBundleURLSchemes` OAuth redirect.)
6. **Configure the Supabase Google provider** (section 3).

**Implementation's first step is a spike** on the staging Firebase/GCP project to
pin down the exact triggers for iOS OAuth client creation and Web client secret
availability (currently uncertain — peppercheck-staging shows zero OAuth clients
after iOS app registration). The spike outcome fixes the wording of the manual
checkpoints in step 4.

### 3. Supabase Google provider configuration

Both client IDs are non-secret (they ship in the app). Source them from the
re-downloaded configs:

- Web client ID = `google-services.json` `default_web_client_id`.
- iOS client ID = `GoogleService-Info-<Cap>.plist` `CLIENT_ID`.

**dev (local Supabase) — `config.toml` needs no structural change.** It already
has:

```toml
[auth.external.google]
enabled = true
client_id = "env(GOOGLE_CLIENT_ID)"
secret = "env(GOOGLE_CLIENT_SECRET)"
skip_nonce_check = true   # correct: the native flow passes no nonce
```

The Supabase CLI auto-loads `supabase/.env` (gitignored). The script sets:

```
GOOGLE_CLIENT_ID=<dev web client>,<dev ios client>   # Web first
GOOGLE_CLIENT_SECRET=<dev web client secret>
```

Update the tracked `supabase/.env.example` to document the comma-separated
format. Apply with `supabase stop && supabase start` (or the db-reset script).

**production (hosted Supabase) — Management API.**
`PATCH https://api.supabase.com/v1/projects/{prod_ref}/config/auth` with
`external_google_enabled=true`,
`external_google_client_id="<prod web>,<prod ios>"`,
`external_google_secret=<prod web secret>`. Additive: in practice this appends
the prod iOS client to the existing *Client IDs*; the secret is already set
(the webapp uses it). Implementation-time check: confirm the prod iOS client is
present after the PATCH and that existing sign-in still works.

### 4. dev FCM service account automation — `scripts/setup/bootstrap-peppercheck-dev-sa.sh`

Needed so the dev push e2e test is reproducible. Today **no** script wires the
dev service account into local Edge Functions — only staging/production →
GitHub Secret is automated, and there is no dev SA bootstrap at all. FCM tokens
are project-scoped, so the dev app's token can only be delivered to by the
**peppercheck-dev** service account.

New dedicated script (mirrors `bootstrap-peppercheck-staging-sa.sh`; additive,
kept separate from `setup-google-signin.sh` because it is push, not sign-in):

1. Idempotently create a peppercheck-dev service account with the FCM Sender
   role via `gcloud`.
2. Download the key to `~/.config/peppercheck/peppercheck-dev-sa.json`
   (mode 0600).
3. Minify and write it into `supabase/functions/.env` as
   `FIREBASE_SERVICE_ACCOUNT_JSON` (create the file from `.env.example` if
   absent; preserve other keys). Raw JSON, no wrapping quotes.

### 5. Secrets & files layout

| Secret / file | Location | Tracked? |
| --- | --- | --- |
| Supabase Management API PAT, prod Web client secret | `~/.config/peppercheck-secrets/` | operator-local |
| dev service account JSON | `~/.config/peppercheck/peppercheck-dev-sa.json` (0600) | operator-local |
| dev Google client IDs + secret | `supabase/.env` | gitignored |
| dev `FIREBASE_SERVICE_ACCOUNT_JSON` | `supabase/functions/.env` | gitignored |
| iOS redirect scheme | `ios/Flutter/Secrets/<Cap>.secrets.xcconfig` | gitignored |
| Per-flavor Firebase config | `android/app/src/<flavor>/google-services.json`, `ios/Runner/Firebase/GoogleService-Info-<Cap>.plist` | gitignored |

Client IDs themselves are non-secret. **No secret is committed.**

## Verification (roadmap task 1.13 + #425 deferred push e2e)

Single PR → per-PR `flutter build` only; one consolidated real-device pass at
the end. Sign-in and push are tested as one flow, because a signed-in user is the
prerequisite for the FCM-token push test.

**dev (local Supabase + peppercheck-dev):**

1. Build the dev flavor: Android (emulator OK) and iOS (real device for the push
   leg; simulator is fine for the sign-in leg).
2. Google Sign-In succeeds on both platforms (Android `aud` = Web client, iOS
   `aud` = iOS client; both authorized in the local `client_id` list).
3. Sign-in triggers an FCM token upsert (`fcm_service` re-upserts on auth-state
   change).
4. Push e2e: run `SELECT notify_event('<signed-in user_id>',
   '<existing notification template key>', ...)` against the local DB →
   `send-notification` → the push arrives on the device. Reuse an existing
   `notification_*_tasker` / `notification_*_referee` key; add no debug-only
   i18n or schema.

Prerequisites for the push leg: `supabase functions serve send-notification`
running; vault secrets seeded via `supabase/snippets/setup_secrets.sql`;
`supabase/functions/.env` `FIREBASE_SERVICE_ACCOUNT_JSON` = peppercheck-dev
(from section 4).

**production (regression only):** confirm that appending the prod iOS client to
the Supabase *Client IDs* does not break existing sign-in (Android + iOS) and
that the existing push path still works (prod `send-notification` already runs on
the prod service account).

**Acceptance criteria:**

- [ ] dev: Google Sign-In succeeds on Android and iOS against local Supabase.
- [ ] dev: a push reaches the signed-in user end to end (closes the #425
      deferral).
- [ ] production: no sign-in regression after the *Client IDs* append.
- [ ] staging is untouched (tracked by #429).

## Companion issue / doc updates

- **#427** (this issue): acceptance changes from "all three flavors" to "dev
  (local) + production"; scope reflects no-app-change, both-client-IDs, and the
  dev SA automation.
- **#429**: expand scope to include staging Google Sign-In via
  `setup-google-signin.sh staging` (run after the staging Play app and its Play
  App Signing SHA exist). The staging service account is already handled by the
  existing bootstrap.
- **#449**: fold in the deploy/auth doc fixes for
  `developer-docs/guide/deployment-flow.adoc` (`FIREBASE_APP_ID`, the
  internal-testers group name) in the same PR, per the #427 issue comment.
- **Roadmap design doc** (`2026-05-11-multi-environment-setup-roadmap-design.md`):
  minimal correction notes with forward pointers added inline at the OAuth-clients
  section, tasks 1.9–1.13, and the "Web OAuth client architecture" open question
  (this document is authoritative for the corrected approach).

## Decisions log

- **D1 (revised):** No app change. Android auto-detects the Web client from
  `google-services.json`; iOS uses its own client from `GoogleService-Info.plist`;
  each Supabase project authorizes both client IDs (Web first). Supersedes the
  original "unify on Web client via `serverClientId`".
- **D2:** Firebase-CLI-driven, semi-manual automation. No REST API creates
  consumer OAuth clients; iOS client creation, Web secret retrieval, and the
  consent screen are Console-manual.
- **D3:** Production reuses existing clients; the change is additive and
  backward compatible.
- **D4:** Supabase config via the Management API (hosted) and `config.toml` +
  `supabase/.env` (local).
- **D5:** #427 scope = dev + production; staging deferred to #429.
- **D6:** The script is env-parameterized and reusable
  (`setup-google-signin.sh <env>`).
- **D7:** Companion updates to #427 / #429 / #449 and the roadmap doc (above).
- **D8 (new):** dev FCM service account is wired by a new dedicated
  `bootstrap-peppercheck-dev-sa.sh` (option a), creating a dedicated gcloud
  service account, kept separate from the sign-in script.

## Open items resolved during design

- Both local `config.toml` `client_id` and hosted `external_google_client_id`
  accept a comma-separated client-ID list (Web first) — verified via Context7 /
  Supabase docs.
- `skip_nonce_check = true` is correct: `authentication_repository.dart` passes
  no nonce.

## Open item for implementation (spike first)

- Exact triggers for iOS OAuth client creation and Web client secret
  availability in a Firebase-managed project. Resolve by a spike on
  peppercheck-staging before finalizing the manual checkpoints in the script.
