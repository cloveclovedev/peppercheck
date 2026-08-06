import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';

import 'auth_repository_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<GoogleSignIn>(),
  MockSpec<GoogleSignInAccount>(),
  MockSpec<GoogleSignInAuthentication>(),
  MockSpec<Logger>(),
  MockSpec<UserCredential>(),
  MockSpec<User>(),
])
void main() {
  late MockFirebaseAuth auth;
  late MockGoogleSignIn google;
  late AuthRepository repo;

  setUp(() {
    auth = MockFirebaseAuth();
    google = MockGoogleSignIn();
    repo = AuthRepository(
      firebaseAuth: auth,
      googleSignIn: google,
      logger: MockLogger(),
    );
  });

  test(
    'signInWithGoogle exchanges the Google idToken for a Firebase sign-in',
    () async {
      final account = MockGoogleSignInAccount();
      final gAuth = MockGoogleSignInAuthentication();
      when(gAuth.idToken).thenReturn('google-id-token');
      when(account.authentication).thenReturn(gAuth);
      when(google.authenticate()).thenAnswer((_) async => account);
      when(
        auth.signInWithCredential(any),
      ).thenAnswer((_) async => MockUserCredential());

      await repo.signInWithGoogle();

      final captured =
          verify(auth.signInWithCredential(captureAny)).captured.single
              as AuthCredential;
      expect(captured.providerId, 'google.com');
    },
  );

  test(
    'googleCredential returns a Google credential without signing in',
    () async {
      final account = MockGoogleSignInAccount();
      final gAuth = MockGoogleSignInAuthentication();
      when(gAuth.idToken).thenReturn('google-id-token');
      when(account.authentication).thenReturn(gAuth);
      when(google.authenticate()).thenAnswer((_) async => account);

      final credential = await repo.googleCredential();

      expect(credential.providerId, 'google.com');
      verifyNever(auth.signInWithCredential(any));
    },
  );

  test('signOut runs each leg independently even if one throws', () async {
    when(google.signOut()).thenThrow(Exception('google boom'));
    when(auth.signOut()).thenAnswer((_) async {});

    await repo.signOut(); // must not throw

    verify(auth.signOut()).called(1);
    verify(google.signOut()).called(1);
  });

  test(
    'idToken delegates to the current Firebase user with forceRefresh',
    () async {
      final user = MockUser();
      when(user.getIdToken(true)).thenAnswer((_) async => 'tok');
      when(auth.currentUser).thenReturn(user);

      final t = await repo.idToken(forceRefresh: true);

      expect(t, 'tok');
      verify(user.getIdToken(true)).called(1);
    },
  );

  test('idToken returns null when signed out', () async {
    when(auth.currentUser).thenReturn(null);
    expect(await repo.idToken(forceRefresh: false), isNull);
  });
}
