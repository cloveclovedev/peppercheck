# Phase 2 Auth Operator/Infra Checklist

This is a per-environment operator runbook for the Phase 2 identity work
(Firebase-authenticated `/api/v1/me`, Flutter Google/Apple sign-in). Complete
the steps for an environment (dev / staging / production) **before** that
environment's release ships the corresponding client or backend code. Steps
are grouped by environment where the action is per-Firebase-project, and
called out once where the action is shared or per-platform.

Firebase Authentication's Google and Apple social sign-in are used at no
incremental cost within the free tier (up to 50k MAU); no billing change is
required to complete this checklist.

Environments map to separate Firebase projects (dev / staging / production),
each with its own OAuth clients, SHA fingerprints, and provider configuration.
Actions taken in one project's console do not carry over to another.

## 1. Firebase — Google sign-in provider

*Ties to: Flutter Google e2e (P2-5)*

Google currently flows through Supabase; Firebase Auth Google enablement is
net-new for this refactor.

- [ ] Dev: enable Google provider — Firebase Console → Authentication →
      Sign-in method
- [ ] Staging: enable Google provider
- [ ] Production: enable Google provider
- [ ] For each project, confirm the OAuth consent screen (app name, support
      email, logo) is configured and not stuck in a state that blocks sign-in

## 2. Firebase — one account per email address

*Ties to: Flutter Google + Apple e2e (P2-5, P2-6)*

- [ ] Dev: Authentication → Settings → confirm "One account per email
      address" is set to auto-link trusted, verified providers, so Google and
      Apple sign-in with the same verified email converge to a single
      Firebase UID
- [ ] Staging: confirm the same setting
- [ ] Production: confirm the same setting

## 3. Android SHA-1 / SHA-256 fingerprints per flavor

*Ties to: Flutter Google e2e (P2-5)*

Google sign-in fails on Android without the correct SHA fingerprints
registered against the matching Firebase project. Each flavor (`dev`,
`staging`, `production`) signs with a different key.

- [ ] Dev: register SHA-1 **and** SHA-256 of the debug keystore
      (`~/.config/.android/debug.keystore`) in the dev Firebase project
- [ ] Staging: register SHA-1 **and** SHA-256 of the staging signing key in
      the staging Firebase project
- [ ] Production: register SHA-1 **and** SHA-256 of the production signing
      key in the production Firebase project

## 4. Firebase — Apple sign-in provider

*Ties to: Apple e2e (P2-6)*

- [ ] Dev: enable Apple provider — Firebase Console → Authentication →
      Sign-in method; register the Services ID and Sign in with Apple key
      from step 5
- [ ] Staging: enable Apple provider; register Services ID + key
- [ ] Production: enable Apple provider; register Services ID + key

## 5. Apple Developer — capability, Services ID, and key

*Ties to: Apple e2e (P2-6)*

- [ ] Dev: add the "Sign in with Apple" capability to the dev App ID; create
      (or reuse) the Services ID and the Sign in with Apple key used as input
      to step 4
- [ ] Staging: add the capability to the staging App ID; create the Services
      ID and key
- [ ] Production: add the capability to the production App ID; create the
      Services ID and key

## 6. Xcode — Sign in with Apple capability per flavor scheme

*Ties to: iOS Xcode capability task (P2-6.4)*

- [ ] Dev scheme (`dev.xcscheme`): Sign in with Apple capability added to the
      Runner target
- [ ] Staging scheme (`staging.xcscheme`): capability added
- [ ] Production scheme (`production.xcscheme`): capability added

## 7. `FIREBASE_PROJECT_ID` injection for the deployed API

*Ties to: backend auth foundation (P2-2, already merged)*

The Go api's token verifier currently defaults to a dummy local project ID.
Deployed environments must inject the real per-project ID.

- [ ] Staging: set `FIREBASE_PROJECT_ID` to the staging Firebase project ID
      in the staging deployment config/secrets
- [ ] Production: set `FIREBASE_PROJECT_ID` to the production Firebase
      project ID in the production deployment config/secrets

(Dev/local may keep the default unless testing against a real Firebase
project locally.)

## 8. End-to-end smoke test (per platform, real device)

*Ties to: Flutter Google + Apple e2e (P2-5, P2-6); run once all prior steps
for the environment are complete*

- [ ] Android, real device: sign in with Google using a verified email;
      confirm a single internal user via `GET /api/v1/me`
- [ ] Android, real device: sign in with Apple using the **same** verified
      email; confirm `/api/v1/me` returns the **same** internal `user.id` as
      the Google sign-in (one Firebase UID → one internal user)
- [ ] iOS, real device: repeat the same Google → Apple, same-email
      convergence check
- [ ] Either platform: sign in with Apple using "Hide My Email" (a relay
      address) and confirm it resolves to a **separate** internal user, not
      merged with the verified-email account above
- [ ] Repeat this smoke test once per environment before that environment's
      release (dev now; staging and production before their respective
      releases)
