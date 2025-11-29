import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'authentication_repository.g.dart';

class AuthenticationRepository {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      if (!_googleSignIn.supportsAuthenticate()) {
        throw Exception('Google Sign-In is not supported on this platform.');
      }

      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      return account;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

@Riverpod(keepAlive: true)
AuthenticationRepository authenticationRepository(Ref ref) {
  return AuthenticationRepository();
}
