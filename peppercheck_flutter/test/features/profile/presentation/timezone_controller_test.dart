import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';
import 'package:peppercheck_flutter/features/profile/presentation/providers/current_profile_provider.dart';
import 'package:peppercheck_flutter/features/profile/presentation/timezone_controller.dart';
import 'package:logger/logger.dart';

import 'timezone_controller_test.mocks.dart';

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
      final profile = Profile(id: userId, timezone: dbTimezone);

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
      when(
        mockProfileRepository.fetchProfile(userId),
      ).thenAnswer((_) async => profile);

      final container = await makeContainer(userId: userId);

      // Act
      // Reading the controller triggers build -> fetch profile -> check timezone
      await container.read(currentProfileProvider.future);
      await container.read(timezoneControllerProvider.future);

      // Assert
      verify(
        mockProfileRepository.updateTimezone(userId, deviceTimezone),
      ).called(1);
    },
  );

  test(
    'Do NOT update timezone when device timezone matches DB timezone',
    () async {
      // Arrange
      const userId = 'user-123';
      const dbTimezone = 'Asia/Tokyo';
      const deviceTimezone = 'Asia/Tokyo';
      final profile = Profile(id: userId, timezone: dbTimezone);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (
            methodCall,
          ) async {
            if (methodCall.method == 'getLocalTimezone') {
              return deviceTimezone;
            }
            return null;
          });

      when(
        mockProfileRepository.fetchProfile(userId),
      ).thenAnswer((_) async => profile);

      final container = await makeContainer(userId: userId);

      // Act
      await container.read(currentProfileProvider.future);
      await container.read(timezoneControllerProvider.future);

      // Assert
      verifyNever(mockProfileRepository.updateTimezone(any, any));
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
    await container.read(timezoneControllerProvider.future);

    // Assert
    verifyNever(mockProfileRepository.fetchProfile(any));
    verifyNever(mockProfileRepository.updateTimezone(any, any));
  });
}
