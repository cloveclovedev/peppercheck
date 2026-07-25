import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/app/config/app_environment.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('dev on Android emulator uses 10.0.2.2 over cleartext', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.dev, isAndroid: true),
        'http://10.0.2.2',
      );
    });

    test('dev on iOS simulator uses 127.0.0.1 over cleartext', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.dev, isAndroid: false),
        'http://127.0.0.1',
      );
    });

    test('staging is HTTPS regardless of platform', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.staging, isAndroid: true),
        'https://staging.peppercheck.dev',
      );
      expect(
        resolveApiBaseUrl(AppEnvironment.staging, isAndroid: false),
        'https://staging.peppercheck.dev',
      );
    });

    test('production is HTTPS regardless of platform', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.production, isAndroid: true),
        'https://peppercheck.dev',
      );
    });
  });
}
