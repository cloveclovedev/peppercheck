import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/auth/data/apple_nonce.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

part 'auth_repository.g.dart';

/// Raised when Apple's email matches an existing account under a different
/// provider that Firebase will not auto-link. The UI must obtain explicit user
/// consent before calling [AuthRepository.linkAppleToExisting]. Never merge on
/// an email string alone.
class AccountLinkRequiredException implements Exception {
  const AccountLinkRequiredException(this.email, this.pendingCredential);
  final String? email;
  final AuthCredential pendingCredential;
}

/// Firebase authentication adapter. This is the ONLY place that imports
/// `firebase_auth`. Google sign-in exchanges the Google ID token for a Firebase
/// credential; sign-out runs each leg independently and idempotently.
class AuthRepository {
  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required Logger logger,
  }) : _auth = firebaseAuth,
       _google = googleSignIn,
       _logger = logger;

  /// Test-only constructor for Apple sign-in/link tests, which never touch
  /// Google or the logger.
  AuthRepository.forAppleTest(FirebaseAuth firebaseAuth)
    : _auth = firebaseAuth,
      _google = GoogleSignIn.instance,
      _logger = Logger();

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final Logger _logger;

  Future<void> signInWithGoogle() async {
    final credential = await googleCredential();
    await _auth.signInWithCredential(credential);
  }

  /// Runs the Google sign-in flow and returns the resulting Firebase
  /// [AuthCredential] without signing in. Used to obtain a fresh "existing
  /// provider" credential when the UI links Apple onto a Google account (see
  /// [linkAppleToExisting]).
  Future<AuthCredential> googleCredential() async {
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in returned no ID token');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<void> signInWithApple() async {
    final nonce = generateAppleNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce.sha256Hex,
    );
    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw StateError('Apple sign-in returned no identity token');
    }
    await completeAppleSignIn(idToken: idToken, rawNonce: nonce.raw);
  }

  /// Exchanges the Apple identity token for a Firebase sign-in. On
  /// account-exists-with-different-credential, raises
  /// [AccountLinkRequiredException] instead of silently creating a second user.
  Future<void> completeAppleSignIn({
    required String idToken,
    required String rawNonce,
  }) async {
    final credential = OAuthProvider(
      'apple',
    ).credential(idToken: idToken, rawNonce: rawNonce);
    try {
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw AccountLinkRequiredException(e.email, credential);
      }
      // Surface the server reason (Firebase often hides it behind
      // internal-error); useful while wiring up the Apple provider config.
      _logger.e(
        'Apple sign-in failed: code=${e.code} message=${e.message}',
        error: e,
      );
      rethrow;
    }
  }

  /// Links the pending Apple credential onto the existing account. Call ONLY
  /// after explicit user consent and after re-authenticating with [existing].
  Future<void> linkAppleToExisting({
    required AuthCredential pending,
    required AuthCredential existing,
  }) async {
    await _auth.signInWithCredential(existing);
    final user = _auth.currentUser;
    if (user == null) throw StateError('re-auth failed before linking');
    await user.linkWithCredential(pending);
  }

  /// Signs out of every provider. Each leg is attempted independently so one
  /// failure does not abandon the others (replaces the old `Future.wait`,
  /// which lost partial failures). Phase 3 adds FCM unregister; Phase 5 adds
  /// RevenueCat logout — each as its own guarded leg here.
  Future<void> signOut() async {
    await _guard('google', () => _google.signOut());
    await _guard('firebase', () => _auth.signOut());
  }

  /// The current Firebase ID token, or null when signed out. Backs the
  /// `IdTokenProvider` seam consumed by `core/network`.
  Future<String?> idToken({required bool forceRefresh}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  Future<void> _guard(String leg, Future<void> Function() op) async {
    try {
      await op();
    } catch (e, st) {
      _logger.w('sign-out leg "$leg" failed', error: e, stackTrace: st);
    }
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn.instance,
    logger: ref.watch(loggerProvider),
  );
}
