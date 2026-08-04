import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';
import 'package:peppercheck_flutter/features/profile/ui/current_profile_provider.dart';

import 'current_profile_provider_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ProfileRepository>()])
void main() {
  late MockProfileRepository mockProfileRepository;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
  });

  // Async because `current_profile_provider.dart` reads `currentAppUserProvider`
  // synchronously (`.value`), relying on the app router having already
  // resolved it before any profile screen is reachable (see
  // `app_router.dart`'s redirect gate). Awaiting the override's future here
  // reproduces that precondition instead of racing against `/me` resolution.
  test('resolves to the fetched Profile when signed in', () async {
    const profile = Profile(username: 'tanaka', timezone: 'Asia/Tokyo');
    when(mockProfileRepository.fetchOwn()).thenAnswer((_) async => profile);

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
    await container.read(currentAppUserProvider.future);

    final result = await container.read(currentProfileProvider.future);

    expect(result, profile);
    verify(mockProfileRepository.fetchOwn()).called(1);
  });

  test('is not fetched when signed out', () async {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        currentAppUserProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentAppUserProvider.future);

    final result = await container.read(currentProfileProvider.future);

    expect(result, isNull);
    verifyNever(mockProfileRepository.fetchOwn());
  });
}
