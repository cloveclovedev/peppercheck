import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';

void main() {
  test('carries stable code, message, requestId, statusCode', () {
    const e = ApiException(
      code: 'unauthenticated',
      message: 'no token',
      requestId: 'req-1',
      statusCode: 401,
    );
    expect(e.code, 'unauthenticated');
    expect(e.statusCode, 401);
    expect(e.requestId, 'req-1');
    expect(e.toString(), contains('unauthenticated'));
  });

  test('network and timeout named constructors set their codes', () {
    expect(const ApiException.network().code, 'network');
    expect(const ApiException.timeout().code, 'timeout');
    expect(const ApiException.tokenUnavailable().code, 'token_unavailable');
  });
}
