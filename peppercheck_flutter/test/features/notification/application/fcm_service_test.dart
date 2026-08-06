import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/notification/application/fcm_service.dart';
import 'package:peppercheck_flutter/features/notification/data/notification_repository.dart';

import 'fcm_service_test.mocks.dart';

// Scratch provider that yields its own `Ref`, bound to the test container.
// `FcmService` is a plain class (not an AsyncNotifier/generated provider), so
// tests construct it directly rather than through `fcmServiceProvider` (which
// wires `ref.listen(authStateChangesProvider, ...)` and would touch the real
// Firebase Auth stream).
final _refProvider = Provider<Ref>((ref) => ref);

@GenerateNiceMocks([MockSpec<NotificationRepository>()])
void main() {
  late MockNotificationRepository notificationRepository;

  setUp(() {
    notificationRepository = MockNotificationRepository();
    when(
      notificationRepository.registerToken(any, any),
    ).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer({required bool signedIn}) {
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(
          notificationRepository,
        ),
        isFirebaseAuthenticatedProvider.overrideWithValue(signedIn),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'registerToken forwards to the repository on the token-refresh path when signed in',
    () async {
      final container = makeContainer(signedIn: true);
      final service = FcmService(container.read(_refProvider));

      await service.registerToken('tok-123');

      verify(notificationRepository.registerToken('tok-123', any)).called(1);
    },
  );

  test('registerToken is a no-op while signed out', () async {
    final container = makeContainer(signedIn: false);
    final service = FcmService(container.read(_refProvider));

    await service.registerToken('tok-123');

    verifyNever(notificationRepository.registerToken(any, any));
  });

  test(
    'onSignedIn retries the upsert with the current token when signed in',
    () async {
      final container = makeContainer(signedIn: true);
      final service = FcmService(
        container.read(_refProvider),
        getToken: () async => 'tok-456',
      );

      await service.onSignedIn();

      verify(notificationRepository.registerToken('tok-456', any)).called(1);
    },
  );

  test('onSignedIn does not register when there is no token', () async {
    final container = makeContainer(signedIn: true);
    final service = FcmService(
      container.read(_refProvider),
      getToken: () async => null,
    );

    await service.onSignedIn();

    verifyNever(notificationRepository.registerToken(any, any));
  });
}
