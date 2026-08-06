import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_errors.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/ui/username_edit_view_model.dart';

import 'username_edit_view_model_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ProfileRepository>()])
void main() {
  late MockProfileRepository mockProfileRepository;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockProfileRepository = MockProfileRepository();
  });

  // The view model reads `currentProfileProvider`, which in turn watches
  // `currentAppUserProvider` to gate the fetch (see `app_router.dart`'s
  // redirect gate for the same precondition in production).
  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        currentAppUserProvider.overrideWith(
          (ref) async => AppUser(
            internalUserId: 'user-123',
            issuer: 'iss',
            status: 'active',
            createdAt: DateTime.utc(2026),
          ),
        ),
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
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(username: 'a', onSuccess: () => successCalled = true);

      final state = container.read(usernameEditViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('tooShort'));
      verifyNever(mockProfileRepository.updateUsername(any));
      expect(successCalled, isFalse);
    });

    test('rejects values longer than 20 characters', () async {
      final container = makeContainer();
      await container
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(username: 'a' * 21, onSuccess: () {});

      final state = container.read(usernameEditViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('tooLong'));
      verifyNever(mockProfileRepository.updateUsername(any));
    });

    test('rejects values containing emoji', () async {
      final container = makeContainer();
      await container
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(username: 'hello🍀', onSuccess: () {});

      final state = container.read(usernameEditViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('invalidChars'));
      verifyNever(mockProfileRepository.updateUsername(any));
    });

    test('rejects values containing punctuation/symbols', () async {
      final container = makeContainer();
      await container
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(username: 'tanaka@home', onSuccess: () {});

      final state = container.read(usernameEditViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals('invalidChars'));
    });

    test('accepts Japanese characters', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('たなか花子'),
      ).thenAnswer((_) async {});

      await container
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(username: 'たなか花子', onSuccess: () {});

      verify(mockProfileRepository.updateUsername('たなか花子')).called(1);
      expect(container.read(usernameEditViewModelProvider).hasError, isFalse);
    });

    test('trims whitespace before validation and submission', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('tanaka'),
      ).thenAnswer((_) async {});

      await container
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(username: '  tanaka  ', onSuccess: () {});

      verify(mockProfileRepository.updateUsername('tanaka')).called(1);
    });

    test('calls repository and onSuccess on valid input', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('tanaka'),
      ).thenAnswer((_) async {});

      var successCalled = false;
      await container
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(
            username: 'tanaka',
            onSuccess: () => successCalled = true,
          );

      verify(mockProfileRepository.updateUsername('tanaka')).called(1);
      expect(successCalled, isTrue);
      expect(container.read(usernameEditViewModelProvider).hasError, isFalse);
    });

    test('surfaces UsernameAlreadyTakenException as error state', () async {
      final container = makeContainer();
      when(
        mockProfileRepository.updateUsername('existing'),
      ).thenThrow(const UsernameAlreadyTakenException());

      var successCalled = false;
      await container
          .read(usernameEditViewModelProvider.notifier)
          .updateUsername(
            username: 'existing',
            onSuccess: () => successCalled = true,
          );

      final state = container.read(usernameEditViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<UsernameAlreadyTakenException>());
      expect(successCalled, isFalse);
    });
  });
}
