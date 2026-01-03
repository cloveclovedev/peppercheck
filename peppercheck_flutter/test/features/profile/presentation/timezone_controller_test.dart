import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';
import 'package:peppercheck_flutter/features/profile/presentation/providers/current_profile_provider.dart';
import 'package:peppercheck_flutter/features/profile/presentation/timezone_controller.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Helper to create a basic validated User
  User createMockUser(String id) {
    return User(
      id: id,
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  ProviderContainer makeContainer({required String userId}) {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        loggerProvider.overrideWithValue(mockLogger),
        currentUserProvider.overrideWithValue(createMockUser(userId)),
      ],
    );
    addTearDown(container.dispose);
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

      final container = makeContainer(userId: userId);

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

      final container = makeContainer(userId: userId);

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
        currentUserProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    // Act
    await container.read(timezoneControllerProvider.future);

    // Assert
    verifyNever(mockProfileRepository.fetchProfile(any));
    verifyNever(mockProfileRepository.updateTimezone(any, any));
  });
}
