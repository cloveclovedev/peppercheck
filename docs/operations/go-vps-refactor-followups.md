# Go/VPS refactor — remaining work & follow-ups

Living checklist so nothing is forgotten. The full roadmap lives in the strategy
spec (`docs/superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md`);
this file tracks the concrete near-term items. Last updated: 2026-07-25 (after
Phase 2 merge, PR #467 → `refactor/go-api-vps` `5221d8c`).

Status: **Phase 2 (identity & client boundary) is DONE** — backend #466 + Flutter
#467. Google (iOS/Android) + Apple (iOS) sign-in verified on dev; same verified
email converges to one internal user.

---

## 1. Phase 2 operator tasks — release stage (dev is done; staging/prod pending)

Firebase / Apple Developer / Play Console config, per environment. Check current
state anytime with `scripts/phase2-auth-preflight.sh peppercheck-dev peppercheck-staging peppercheck-474211`.
Reference: `docs/operations/phase2-auth-operator-checklist.md`,
`docs/operations/firebase-apple-signin-method.md`.

- [ ] **staging (`peppercheck-staging`)**: create the app in Play Console; enable
      Google + Apple sign-in providers in Firebase; register the Play App Signing
      **SHA-1 + SHA-256** (currently only a `0000…` dummy is registered).
- [ ] **prod (`peppercheck-474211`)**: enable Google + Apple providers in Firebase;
      register the **real Play App Signing** SHA-1 + SHA-256 (currently the debug
      key SHA `e6c517…` is registered, which is wrong for release). Register with
      `scripts/register-android-sha.sh --project <p> --package <pkg> --sha1 .. --sha256 ..`
      (values from Play Console → Setup → App signing).
- [ ] **All envs**: confirm Firebase Auth → Settings → **"one account per email"**
      is ON — this is what makes Google + Apple (same verified email) converge to
      one account. (Auto-linking is the ONLY convergence mechanism now; there is no
      manual link flow.)
- [ ] **iOS Sign in with Apple capability**: dev/staging/prod App IDs exist in
      Apple Developer with the capability enabled (dev confirmed). Project-side
      entitlements are wired in-repo; run/verify with
      `scripts/phase2-ios-apple-signin-wire.sh` if needed. Team ID `WHVHQ5952G`.
- [ ] **`FIREBASE_PROJECT_ID` injection** for the deployed api (staging/prod) —
      belongs to the Phase 7 deploy, not needed for local dev.
- Note: the Firebase Apple provider **Services ID + OAuth code-flow** config is
      OPTIONAL for the native flow (dev works via `signInWithProvider` without it);
      dev has it set (harmless). Only needed for web/Android Apple or token
      revocation (Phase 6).

## 2. Phase 2 deferred code polish (nice-to-have, not blocking)

- [ ] Remove the now-dead slang keys `login.appleLink.*` from
      `peppercheck_flutter/assets/i18n/ja.i18n.json` (the consent dialog was
      removed when Apple moved to `signInWithProvider`), then regenerate slang.
- [ ] `login_screen.dart`: hardcoded English error strings → i18n slang keys.
- [ ] Apple button has no loading spinner (Google does) — cosmetic.
- [ ] `auth_repository.dart` `googleCredential()` could be inlined into
      `signInWithGoogle()` (it was extracted for the removed Apple-link flow).
- [ ] `api_client.dart` stale "interceptor" comment (~line 44; design uses inline
      retry, no interceptor).
- [ ] Pre-existing uncommitted `evidence_controller.g.dart` + untracked files
      (`.agents/`, other-phase plan/spec docs, `supabase/snippets/*.sql`) — decide
      what to keep / clean up.
- [ ] The "Dio construction only in `core/network`" CI import check is
      **intentionally deferred** until evidence/profile migrate (they still build
      Dio for R2 uploads). Re-enable it in those features' phase.

## 3. Phase 3 (profile / notification) — carry-overs from Phase 2

- [ ] **Username generation** (bounded 5-attempt retry) — Phase 2 provisioning
      creates no username/profile; port the retry logic here.
- [ ] **Re-enable FCM token sync** — gated OFF in Phase 2
      (`notification_repository.dart` upsert/delete are disabled guards).
- [ ] **Migrate the profile feature** — `current_profile` fetches Supabase and is
      non-functional (a `PGRST116` "no profile row" is expected until migrated).
- Spec draft (untracked): `docs/superpowers/specs/2026-07-25-phase3a-profile-notification-design.md`.

## 4. Repo hygiene

- [ ] Delete the merged remote branch `feat/phase2-flutter-identity-client`.

## 5. Later phases (pointers only — details in the strategy spec)

- **Phase 4**: evidence objects on the public R2 domain → private (presigned).
- **Phase 5**: worker job idempotency ([issue #464]), payout idempotency
      (`FOR UPDATE SKIP LOCKED` + unique `stripe_transfer_id`), judgement
      double-confirm lock, Stripe webhook env-var mismatch
      (`STRIPE_WEBHOOK_SIGNING_SECRET` vs `STRIPE_WEBHOOK_SECRET`), Premium price
      JPY 2,580 seed vs 2,480 design, RevenueCat identify + entitlement + webhook.
- **Phase 6**: account-deletion saga (fund-loss safety); Apple token revocation
      (needs the Apple Sign in with Apple key + Firebase OAuth code-flow config).
- **Phase 7**: deploy (DigitalOcean sgp1 + Caddy + Compose), WAL/PITR + pg_dump to
      Backblaze B2, restore/PITR rehearsal, `FIREBASE_PROJECT_ID` injection.

[issue #464]: https://github.com/cloveclovedev/peppercheck/issues/464
