# Phase 2 Auth Operator/Infra Checklist

This is a per-environment operator runbook for the Phase 2 identity work
(Firebase-authenticated `/api/v1/me`, Flutter Google sign-in on iOS/Android,
and Apple sign-in on iOS). Complete the steps for an environment (dev /
staging / production) **before** that environment's release ships the
corresponding client or backend code. Steps are grouped by environment where
the action is per-Firebase-project, and called out once where the action is
shared or per-platform.

This app uses only Google and Apple sign-in (no phone/SMS), which is free at
PepperCheck's scale; there is no billing change required for Phase 2.

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

Phase 2 uses Firebase's native iOS provider flow:
`FirebaseAuth.signInWithProvider(AppleAuthProvider())`. A Services ID and
OAuth code-flow key are not required for this native flow. They are needed
only if Apple sign-in later expands to web/Android, or for Apple token
revocation in Phase 6.

- [ ] Dev: enable Apple provider — Firebase Console → Authentication →
      Sign-in method; verify the native iOS flow
- [ ] Staging: enable Apple provider and verify the native iOS flow
- [ ] Production: enable Apple provider and verify the native iOS flow

## 5. Apple Developer — iOS capability

*Ties to: Apple e2e (P2-6)*

- [ ] Dev: add the "Sign in with Apple" capability to the dev App ID
- [ ] Staging: add the capability to the staging App ID
- [ ] Production: add the capability to the production App ID
- [ ] Create a Services ID and Sign in with Apple key only when implementing
      web/Android Apple sign-in or Phase 6 token revocation

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

## 8. End-to-end smoke test (real devices)

*Ties to: Flutter Google + Apple e2e (P2-5, P2-6); run once all prior steps
for the environment are complete*

- [ ] Android, real device: sign in with Google using a verified email;
      confirm a single internal user via `GET /api/v1/me`
- [ ] iOS, real device: sign in with Google, then Apple using the **same**
      verified email; confirm `/api/v1/me` returns the **same** internal
      `user.id` (one Firebase UID → one internal user)
- [ ] iOS, real device: sign in with Apple using "Hide My Email" (a relay
      address) and confirm it resolves to a **separate** internal user, not
      merged with the verified-email account above
- [ ] Confirm the Apple button is not offered on Android; Android Apple
      sign-in is outside the Phase 2 scope
- [ ] Repeat this smoke test once per environment before that environment's
      release (dev now; staging and production before their respective
      releases)
