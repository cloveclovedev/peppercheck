# Firebase Sign in with Apple — implementation method (Flutter)

**Decision:** Use the Firebase-official, recommended provider flow
`FirebaseAuth.instance.signInWithProvider(AppleAuthProvider())` for Apple
sign-in on mobile. Do **not** use the manual
`sign_in_with_apple` + `OAuthProvider('apple.com').credential(...)` +
`signInWithCredential(...)` path — it is a documented alternative but triggers a
firebase_auth **iOS bug** for the `apple.com` provider.

Google sign-in is unaffected and stays on its official credential flow.

---

## What the official Firebase docs say

Source: **Authenticate with Apple on Flutter** —
<https://firebase.google.com/docs/auth/flutter/federated-auth> (Apple section).

The docs give two approaches:

**Approach A — cross-platform, "recommended" (what we adopt):**

```dart
Future<UserCredential> signInWithApple() async {
  final appleProvider = AppleAuthProvider();
  if (kIsWeb) {
    return FirebaseAuth.instance.signInWithPopup(appleProvider);
  } else {
    return FirebaseAuth.instance.signInWithProvider(appleProvider);
  }
}
```

Scopes and parameters are set on the provider (verified present in
`firebase_auth_platform_interface` `AppleAuthProvider`):

```dart
final provider = AppleAuthProvider()
  ..addScope('email')
  ..addScope('name');
```

**Approach B — Apple platforms only, native, needs external packages:**

```dart
final credential = AppleAuthProvider.credentialWithIDToken(idToken, rawNonce, fullName);
await FirebaseAuth.instance.signInWithCredential(credential);
```

Approach B is the family our Phase 2 code used (via the `sign_in_with_apple`
package and `OAuthProvider('apple.com').credential(idToken:, rawNonce:)`, which
firebase_auth routes to the same native `appleCredentialWithIDToken:rawNonce:`).

## Why we switch away from Approach B

Approach B fails at runtime on iOS with:

```
[firebase_auth/invalid-credential] Invalid OAuth response from apple.com
```

Evidence gathered (2026-07-25, dev / `peppercheck-dev`):

1. The Apple `id_token` is valid: `iss=https://appleid.apple.com`,
   `aud=dev.cloveclove.peppercheck.dev`, verified email, and its `nonce` claim
   equals `SHA-256(rawNonce)` (checked byte-for-byte).
2. The credential itself is accepted by Firebase: posting the exact `id_token` +
   `rawNonce` to the Firebase REST endpoint
   `accounts:signInWithIdp` (`providerId=apple.com`, `nonce=<rawNonce>`)
   **succeeds** and creates the user. So token, nonce, and the Firebase Apple
   provider configuration are all correct.
3. The same request from the app via `signInWithCredential` fails with
   `invalid-credential`. Every layer was inspected (our Dart, `sign_in_with_apple`,
   the firebase_auth plugin, `OAuthCredential.prepare`) and all pass the raw
   nonce unmodified — i.e. the app sends the same request that succeeds over REST.

The **root cause of the client-side failure is not definitively established.**
The credential is valid server-side (evidence 2), so the failure is in how the
firebase_auth iOS SDK submits the manually-built Apple credential through
`signInWithCredential`. Similar-symptom GitHub issues exist but do **not** prove
the same root cause and must not be cited as confirmation:

- **#17466** is about **reusing** a credential obtained from a
  `FirebaseAuthException` and passing it back to
  `signInWithCredential`/`linkWithCredential` — a different flow and a different
  error than our freshly-generated credential.
  <https://github.com/firebase/flutterfire/issues/17466>
- **#10441** turned out to be a duplicate `GoogleService-Info.plist` config
  issue (`resolution: user`), not a Simulator/SDK bug.
- **#12944** / **#11877** are limited to reusing credentials obtained from
  exceptions.

What **is** established:

- `signInWithProvider(AppleAuthProvider())` is Firebase's officially
  **recommended** method (Approach A).
- Our manual path also does not use the current official credential form:
  the latest docs use `AppleAuthProvider.credentialWithIDToken(idToken, rawNonce,
  fullName)`, whereas our code uses `OAuthProvider('apple.com').credential(...)`
  (which firebase_auth routes to the same native call, but is not the documented
  form).

We adopt `signInWithProvider` because it is the recommended path and lets
firebase_auth handle the Apple UI + nonce internally, avoiding the
manual-credential submission that fails here. **This is a plausible fix, not a
guaranteed one** — it must be verified empirically (clean rebuild, and ideally a
real device) before being treated as resolved.

## Google is correct as-is (do not change)

Google uses the official mobile credential flow — `google_sign_in` →
`GoogleAuthProvider.credential(idToken:)` → `signInWithCredential(...)` — and
works on iOS and Android. The #17466 bug is specific to the `apple.com`
provider, so Google is unaffected. Switching Google to `signInWithProvider`
would degrade the native account-picker UX, so it stays on the credential flow.

## Rollout (incremental — do not rewrite everything up front)

1. Swap only `signInWithApple()` to
   `signInWithProvider(AppleAuthProvider()..addScope('email')..addScope('name'))`.
   Leave the existing linking code in place for now.
2. **Clean rebuild** (stop the app, `flutter run --flavor dev`, not just hot
   restart) and verify the primary Apple sign-in succeeds — ideally on a real
   device, since the failure has only been reproduced on the Simulator.
3. Only after it is confirmed working: redesign account linking (below), remove
   the now-unused `sign_in_with_apple` / `apple_nonce.dart` / `crypto`
   (Apple-only usage), and update the Apple tests.

## Account linking — implemented behavior

Confirmed working on iOS (dev, 2026-07-25): Apple sign-in succeeds and the
Google + Apple sign-ins for the same verified email resolve to a **single**
internal user (`users` / `user_identities` each have one row).

- "Same verified email via Google and Apple → one internal user" convergence is
  handled by Firebase's **one-account-per-email** setting (auto-linking trusted,
  verified providers). This is the mechanism; confirm the setting is enabled.
- The manual consent dialog + `completeAppleSignIn` / `linkAppleToExisting`
  (P2-6.3) were **removed** — `signInWithProvider` performs the Apple sign-in
  internally, so we no longer hold an Apple credential to link manually. The
  rare non-auto-link case surfaces as a `FirebaseAuthException` and is shown as
  a plain error (no silent merge on an email match alone). The now-unused
  `apple_nonce.dart` and `crypto` dependency were also removed; the
  `SignInWithAppleButton` widget (and thus the `sign_in_with_apple` package) is
  kept for Apple's HIG-compliant button.

## Process note

For any Firebase integration, read the relevant Firebase official documentation
first and cite the exact documented method before implementing. This file is the
record for the Apple sign-in method.
