import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/features/notification/data/notification_repository.dart';

import 'notification_repository_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ApiClient>()])
void main() {
  test('registerToken PUTs the token and device type', () async {
    final api = MockApiClient();
    when(
      api.putJson('/api/v1/me/device-push-tokens', body: anyNamed('body')),
    ).thenAnswer((_) async {});

    await NotificationRepository(api).registerToken('tok-123', 'android');

    verify(
      api.putJson(
        '/api/v1/me/device-push-tokens',
        body: {'token': 'tok-123', 'deviceType': 'android'},
      ),
    ).called(1);
  });

  test('deregisterToken DELETEs the token', () async {
    final api = MockApiClient();
    when(
      api.deleteJson('/api/v1/me/device-push-tokens', body: anyNamed('body')),
    ).thenAnswer((_) async {});

    await NotificationRepository(api).deregisterToken('tok-123');

    verify(
      api.deleteJson(
        '/api/v1/me/device-push-tokens',
        body: {'token': 'tok-123'},
      ),
    ).called(1);
  });

  test('a slow registerToken started before deregisterToken still completes '
      'its PUT before the DELETE runs, not after', () async {
    // Regression test: a fire-and-forget startup registerToken() can still
    // be in flight when the user signs out and calls deregisterToken(). If
    // the calls raced by network timing instead of invocation order, the
    // DELETE could finish first and the slow PUT could land afterward,
    // silently recreating the token binding the DELETE just removed
    // (the backend upserts on conflict).
    final api = MockApiClient();
    final callOrder = <String>[];
    when(
      api.putJson('/api/v1/me/device-push-tokens', body: anyNamed('body')),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      callOrder.add('PUT');
    });
    when(
      api.deleteJson('/api/v1/me/device-push-tokens', body: anyNamed('body')),
    ).thenAnswer((_) async {
      callOrder.add('DELETE');
    });

    final repo = NotificationRepository(api);
    final register = repo.registerToken('tok-123', 'android');
    final deregister = repo.deregisterToken('tok-123');
    await Future.wait([register, deregister]);

    expect(callOrder, ['PUT', 'DELETE']);
  });

  test(
    'registerToken is a silent no-op while a sign-out is in progress',
    () async {
      // Regression test: a token-refresh event can fire registerToken while
      // SignOutCoordinator's deregister is in flight but Firebase sign-out
      // hasn't completed yet (the signed-in check still passes). Queuing
      // order alone isn't enough — that PUT would still land right after
      // the DELETE and undo it — so it must be dropped outright.
      final api = MockApiClient();
      when(
        api.putJson('/api/v1/me/device-push-tokens', body: anyNamed('body')),
      ).thenAnswer((_) async {});

      final repo = NotificationRepository(api)..beginSignOut();
      await repo.registerToken('tok-123', 'android');

      verifyNever(
        api.putJson('/api/v1/me/device-push-tokens', body: anyNamed('body')),
      );
    },
  );

  test('registerToken resumes normally after endSignOut', () async {
    final api = MockApiClient();
    when(
      api.putJson('/api/v1/me/device-push-tokens', body: anyNamed('body')),
    ).thenAnswer((_) async {});

    final repo = NotificationRepository(api)
      ..beginSignOut()
      ..endSignOut();
    await repo.registerToken('tok-123', 'android');

    verify(
      api.putJson(
        '/api/v1/me/device-push-tokens',
        body: {'token': 'tok-123', 'deviceType': 'android'},
      ),
    ).called(1);
  });
}
