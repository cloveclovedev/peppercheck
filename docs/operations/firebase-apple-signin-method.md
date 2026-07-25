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

This matches a known, still-open firebase_auth issue:

- flutterfire **#17466** — iOS `signInWithCredential` with an Apple credential
  throws `invalid-credential`; the maintainer-accepted workaround is
  `signInWithProvider`. <https://github.com/firebase/flutterfire/issues/17466>
- Related: **#10441** (iOS Simulator Apple sign-in), **#12944**, **#11877**.

`signInWithProvider(AppleAuthProvider())` is therefore both the **officially
recommended** method and the one that avoids the bug.

## Google is correct as-is (do not change)

Google uses the official mobile credential flow — `google_sign_in` →
`GoogleAuthProvider.credential(idToken:)` → `signInWithCredential(...)` — and
works on iOS and Android. The #17466 bug is specific to the `apple.com`
provider, so Google is unaffected. Switching Google to `signInWithProvider`
would degrade the native account-picker UX, so it stays on the credential flow.

## Consequences for the Phase 2 code

- `signInWithApple()` becomes `signInWithProvider(AppleAuthProvider()..addScope('email')..addScope('name'))`.
- The manual nonce (`apple_nonce.dart`) and the `sign_in_with_apple` package are
  no longer needed for the sign-in path (firebase_auth handles the Apple UI and
  nonce internally). Remove them if nothing else uses them.
- Account linking (P2-6.3): with `signInWithProvider`, an existing email under a
  different provider surfaces via a `FirebaseAuthException` (with a `credential`
  to link) rather than the manually-built pending credential. The consent-gated
  linking flow is adjusted accordingly; the "never merge on email alone" rule is
  preserved.

## Process note

For any Firebase integration, read the relevant Firebase official documentation
first and cite the exact documented method before implementing. This file is the
record for the Apple sign-in method.
