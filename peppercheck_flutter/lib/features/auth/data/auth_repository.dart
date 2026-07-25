import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

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

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final Logger _logger;

  Future<void> signInWithGoogle() async {
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in returned no ID token');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
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
