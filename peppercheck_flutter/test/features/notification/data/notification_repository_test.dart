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
}
