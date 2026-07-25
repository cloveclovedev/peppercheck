import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/data/me_repository.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';

import 'current_app_user_test.mocks.dart';

@GenerateNiceMocks([MockSpec<MeRepository>()])
void main() {
  test(
    'currentAppUser resolves the internal user when authenticated',
    () async {
      final me = MockMeRepository();
      when(me.fetchMe()).thenAnswer(
        (_) async => AppUser(
          internalUserId: 'uuid-1',
          issuer: 'iss',
          status: 'active',
          createdAt: DateTime.utc(2026),
        ),
      );

      // Firebase-`User` construction is awkward to stub directly, so override
      // the intermediate boolean seam instead (permitted by the task brief).
      final container = ProviderContainer(
        overrides: [
          meRepositoryProvider.overrideWithValue(me),
          isFirebaseAuthenticatedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final user = await container.read(currentAppUserProvider.future);
      expect(user?.internalUserId, 'uuid-1');
    },
  );

  test('currentAppUser is null when signed out', () async {
    final me = MockMeRepository();

    final container = ProviderContainer(
      overrides: [
        meRepositoryProvider.overrideWithValue(me),
        isFirebaseAuthenticatedProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    final user = await container.read(currentAppUserProvider.future);
    expect(user, isNull);
    verifyNever(me.fetchMe());
  });
}
