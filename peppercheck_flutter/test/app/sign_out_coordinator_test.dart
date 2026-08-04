import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/app/sign_out_coordinator.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';
import 'package:peppercheck_flutter/features/notification/data/notification_repository.dart';

import 'sign_out_coordinator_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NotificationRepository>(),
  MockSpec<AuthRepository>(),
  MockSpec<Logger>(),
])
void main() {
  late MockNotificationRepository notificationRepository;
  late MockAuthRepository authRepository;
  late MockLogger logger;
  late List<String> callOrder;

  setUp(() {
    notificationRepository = MockNotificationRepository();
    authRepository = MockAuthRepository();
    logger = MockLogger();
    callOrder = [];

    when(notificationRepository.deregisterToken(any)).thenAnswer((_) async {
      callOrder.add('deregisterToken');
    });
    when(authRepository.signOut()).thenAnswer((_) async {
      callOrder.add('signOut');
    });
  });

  SignOutCoordinator makeCoordinator({
    required Future<String?> Function() getToken,
    Duration deregisterTimeout = const Duration(seconds: 3),
  }) {
    return SignOutCoordinator(
      notificationRepository: notificationRepository,
      authRepository: authRepository,
      logger: logger,
      getToken: getToken,
      deregisterTimeout: deregisterTimeout,
    );
  }

  test('deregisters the FCM token before signing out of Firebase', () async {
    final coordinator = makeCoordinator(getToken: () async => 'tok-abc');

    await coordinator.signOut();

    expect(callOrder, ['deregisterToken', 'signOut']);
    verify(notificationRepository.deregisterToken('tok-abc')).called(1);
    verify(authRepository.signOut()).called(1);
  });

  test('still signs out of Firebase when FCM deregistration fails', () async {
    when(
      notificationRepository.deregisterToken(any),
    ).thenThrow(Exception('network error'));
    final coordinator = makeCoordinator(getToken: () async => 'tok-abc');

    await expectLater(coordinator.signOut(), completes);

    verify(authRepository.signOut()).called(1);
  });

  test(
    'signs out promptly when deregistration hangs past its timeout',
    () async {
      final coordinator = makeCoordinator(
        getToken: () async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 'tok-abc';
        },
        deregisterTimeout: const Duration(milliseconds: 20),
      );

      await expectLater(coordinator.signOut(), completes);

      verify(authRepository.signOut()).called(1);
      verifyNever(notificationRepository.deregisterToken(any));
    },
  );

  test('skips deregistration when there is no current token', () async {
    final coordinator = makeCoordinator(getToken: () async => null);

    await coordinator.signOut();

    verifyNever(notificationRepository.deregisterToken(any));
    verify(authRepository.signOut()).called(1);
  });
}
