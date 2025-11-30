import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'authentication_repository.g.dart';

class AuthenticationRepository {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final Logger _logger;

  AuthenticationRepository(this._logger);

  Future<AuthResponse> signInWithGoogle() async {
    try {
      if (!_googleSignIn.supportsAuthenticate()) {
        throw Exception('Google Sign-In is not supported on this platform.');
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      return Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e, st) {
      _logger.e('Google Sign-In failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        Supabase.instance.client.auth.signOut(),
      ]);
    } catch (e, st) {
      _logger.e('Sign-Out failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
AuthenticationRepository authenticationRepository(Ref ref) {
  return AuthenticationRepository(ref.watch(loggerProvider));
}
