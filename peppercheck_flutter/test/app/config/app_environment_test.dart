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

    test('dev omits the port when it is the default 80', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.dev, isAndroid: true, devPort: 80),
        'http://10.0.2.2',
      );
    });

    test('dev appends a non-default port on both platforms', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.dev, isAndroid: true, devPort: 5580),
        'http://10.0.2.2:5580',
      );
      expect(
        resolveApiBaseUrl(AppEnvironment.dev, isAndroid: false, devPort: 5580),
        'http://127.0.0.1:5580',
      );
    });

    test('a non-default devPort does not affect staging/production', () {
      expect(
        resolveApiBaseUrl(
          AppEnvironment.staging,
          isAndroid: false,
          devPort: 5580,
        ),
        'https://staging.peppercheck.dev',
      );
      expect(
        resolveApiBaseUrl(
          AppEnvironment.production,
          isAndroid: false,
          devPort: 5580,
        ),
        'https://peppercheck.dev',
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
