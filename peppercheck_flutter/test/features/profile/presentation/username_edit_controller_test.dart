import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_errors.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/presentation/username_edit_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'username_edit_controller_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ProfileRepository>(), MockSpec<Logger>()])
void main() {
  late MockProfileRepository mockProfileRepository;
  late MockLogger mockLogger;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockProfileRepository = MockProfileRepository();
    mockLogger = MockLogger();
  });

  User createMockUser(String id) => User(
    id: id,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        loggerProvider.overrideWithValue(mockLogger),
        currentUserProvider.overrideWithValue(createMockUser('user-123')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('updateUsername', () {
    test('rejects values shorter than 2 characters', () async {
      final container = makeContainer();
      var successCalled = false;

      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(username: 'a', onSuccess: () => successCalled = true);

      final state = container.read(usernameEditControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('tooShort'));
      verifyNever(mockProfileRepository.updateUsername(any, any));
      expect(successCalled, isFalse);
    });

    test('rejects values longer than 20 characters', () async {
      final container = makeContainer();
      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(username: 'a' * 21, onSuccess: () {});

      final state = container.read(usernameEditControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('tooLong'));
      verifyNever(mockProfileRepository.updateUsername(any, any));
    });

    test('rejects values containing emoji', () async {
      final container = makeContainer();
      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(username: 'hello🍀', onSuccess: () {});

      final state = container.read(usernameEditControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('invalidChars'));
      verifyNever(mockProfileRepository.updateUsername(any, any));
    });

    test('rejects values containing punctuation/symbols', () async {
      final container = makeContainer();
      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(username: 'tanaka@home', onSuccess: () {});

      final state = container.read(usernameEditControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('invalidChars'));
    });

    test('accepts Japanese characters', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('user-123', 'たなか花子'),
      ).thenAnswer((_) async {});

      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(username: 'たなか花子', onSuccess: () {});

      verify(
        mockProfileRepository.updateUsername('user-123', 'たなか花子'),
      ).called(1);
      expect(container.read(usernameEditControllerProvider).hasError, isFalse);
    });

    test('trims whitespace before validation and submission', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('user-123', 'tanaka'),
      ).thenAnswer((_) async {});

      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(username: '  tanaka  ', onSuccess: () {});

      verify(
        mockProfileRepository.updateUsername('user-123', 'tanaka'),
      ).called(1);
    });

    test('calls repository and onSuccess on valid input', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('user-123', 'tanaka'),
      ).thenAnswer((_) async {});

      var successCalled = false;
      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(
            username: 'tanaka',
            onSuccess: () => successCalled = true,
          );

      verify(
        mockProfileRepository.updateUsername('user-123', 'tanaka'),
      ).called(1);
      expect(successCalled, isTrue);
      expect(container.read(usernameEditControllerProvider).hasError, isFalse);
    });

    test('surfaces UsernameAlreadyTakenException as error state', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('user-123', 'existing'),
      ).thenThrow(const UsernameAlreadyTakenException());

      var successCalled = false;
      await container
          .read(usernameEditControllerProvider.notifier)
          .updateUsername(
            username: 'existing',
            onSuccess: () => successCalled = true,
          );

      final state = container.read(usernameEditControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<UsernameAlreadyTakenException>());
      expect(successCalled, isFalse);
    });
  });
}
