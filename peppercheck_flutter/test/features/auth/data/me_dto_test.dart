import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/auth/data/me_dto.dart';

void main() {
  test('parses the /api/v1/me envelope and maps to AppUser', () {
    final json = {
      'user': {
        'id': 'uuid-9',
        'status': 'active',
        'createdAt': '2026-07-25T01:02:03Z',
      },
      'identity': {'issuer': 'https://securetoken.google.com/pc-dev'},
    };

    final dto = MeResponse.fromJson(json);
    final user = dto.toDomain();

    expect(user.internalUserId, 'uuid-9');
    expect(user.status, 'active');
    expect(user.issuer, 'https://securetoken.google.com/pc-dev');
    expect(user.createdAt, DateTime.utc(2026, 7, 25, 1, 2, 3));
  });
}
