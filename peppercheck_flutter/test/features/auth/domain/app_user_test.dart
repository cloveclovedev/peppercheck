import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';

void main() {
  test('AppUser holds the internal identity fields', () {
    final u = AppUser(
      internalUserId: 'uuid-1',
      issuer: 'https://securetoken.google.com/pc-dev',
      status: 'active',
      createdAt: DateTime.utc(2026, 7, 25),
    );
    expect(u.internalUserId, 'uuid-1');
    expect(u.issuer, contains('securetoken'));
    expect(u.status, 'active');
  });
}
