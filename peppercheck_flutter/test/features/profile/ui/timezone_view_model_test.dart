import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';
import 'package:peppercheck_flutter/features/profile/ui/current_profile_provider.dart';
import 'package:peppercheck_flutter/features/profile/ui/timezone_view_model.dart';

import 'timezone_view_model_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ProfileRepository>(), MockSpec<Logger>()])
void main() {
  late MockProfileRepository mockProfileRepository;
  late MockLogger mockLogger;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockProfileRepository = MockProfileRepository();
    mockLogger = MockLogger();
  });

  // Async because `current_profile_provider.dart` reads `currentAppUserProvider`
  // synchronously (`.value`), relying on the app router having already
  // resolved it before any profile screen is reachable (see
  // `app_router.dart`'s redirect gate). Awaiting the override's future here
  // reproduces that precondition instead of racing against `/me` resolution.
  Future<ProviderContainer> makeContainer({required String userId}) async {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        loggerProvider.overrideWithValue(mockLogger),
        currentAppUserProvider.overrideWith(
          (ref) async => AppUser(
            internalUserId: userId,
            issuer: 'iss',
            status: 'active',
            createdAt: DateTime.utc(2026),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentAppUserProvider.future);
    return container;
  }

  test(
    'Update timezone when device timezone differs from DB timezone',
    () async {
      // Arrange
      const userId = 'user-123';
      const dbTimezone = 'America/New_York';
      const deviceTimezone = 'Asia/Tokyo';
      const profile = Profile(timezone: dbTimezone);

      // Mock Device Timezone
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (
            methodCall,
          ) async {
            if (methodCall.method == 'getLocalTimezone') {
              return deviceTimezone;
            }
            return null;
          });

      // Mock Repository Response
      when(mockProfileRepository.fetchOwn()).thenAnswer((_) async => profile);

      final container = await makeContainer(userId: userId);

      // Act
      // Reading the view model triggers build -> fetch profile -> check timezone
      await container.read(currentProfileProvider.future);
      await container.read(timezoneViewModelProvider.future);

      // Assert
      verify(mockProfileRepository.updateTimezone(deviceTimezone)).called(1);
    },
  );

  test(
    'Do NOT update timezone when device timezone matches DB timezone',
    () async {
      // Arrange
      const userId = 'user-123';
      const dbTimezone = 'Asia/Tokyo';
      const deviceTimezone = 'Asia/Tokyo';
      const profile = Profile(timezone: dbTimezone);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (
            methodCall,
          ) async {
            if (methodCall.method == 'getLocalTimezone') {
              return deviceTimezone;
            }
            return null;
          });

      when(mockProfileRepository.fetchOwn()).thenAnswer((_) async => profile);

      final container = await makeContainer(userId: userId);

      // Act
      await container.read(currentProfileProvider.future);
      await container.read(timezoneViewModelProvider.future);

      // Assert
      verifyNever(mockProfileRepository.updateTimezone(any));
    },
  );

  test('Do nothing when user is not logged in', () async {
    // Arrange
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        loggerProvider.overrideWithValue(mockLogger),
        currentAppUserProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentAppUserProvider.future);

    // Act
    await container.read(timezoneViewModelProvider.future);

    // Assert
    verifyNever(mockProfileRepository.fetchOwn());
    verifyNever(mockProfileRepository.updateTimezone(any));
  });
}
