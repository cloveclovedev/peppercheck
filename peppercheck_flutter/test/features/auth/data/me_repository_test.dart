import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/features/auth/data/me_repository.dart';

import 'me_repository_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ApiClient>()])
void main() {
  test('fetchMe maps the /api/v1/me envelope to AppUser', () async {
    final api = MockApiClient();
    when(api.getJson('/api/v1/me')).thenAnswer(
      (_) async => {
        'user': {
          'id': 'uuid-3',
          'status': 'active',
          'createdAt': '2026-07-25T00:00:00Z',
        },
        'identity': {'issuer': 'https://securetoken.google.com/pc-dev'},
      },
    );

    final user = await MeRepository(api).fetchMe();

    expect(user.internalUserId, 'uuid-3');
    expect(user.issuer, contains('pc-dev'));
  });
}
