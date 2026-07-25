import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';

import 'apple_sign_in_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<User>(),
  MockSpec<UserCredential>(),
])
void main() {
  test(
    'account-exists-with-different-credential surfaces a link request',
    () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository.forAppleTest(auth);
      when(auth.signInWithCredential(any)).thenThrow(
        FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          email: 'a@example.com',
        ),
      );

      await expectLater(
        () => repo.completeAppleSignIn(
          idToken: 'apple-id-token',
          rawNonce: 'nonce',
        ),
        throwsA(
          isA<AccountLinkRequiredException>()
              .having((e) => e.email, 'email', 'a@example.com')
              // Guards the provider id: Firebase's Apple provider is
              // 'apple.com'; 'apple' is rejected as internal-error.
              .having(
                (e) => e.pendingCredential.providerId,
                'providerId',
                'apple.com',
              ),
        ),
      );
    },
  );

  test('linkAppleToExisting links only after consent (confirm path)', () async {
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(
      auth.signInWithCredential(any),
    ).thenAnswer((_) async => MockUserCredential());
    when(auth.currentUser).thenReturn(user);
    when(
      user.linkWithCredential(any),
    ).thenAnswer((_) async => MockUserCredential());
    final repo = AuthRepository.forAppleTest(auth);

    final apple = OAuthProvider(
      'apple.com',
    ).credential(idToken: 'apple-id-token', rawNonce: 'nonce');
    final existing = GoogleAuthProvider.credential(idToken: 'g');

    await repo.linkAppleToExisting(pending: apple, existing: existing);

    verify(user.linkWithCredential(apple)).called(1);
  });
}
