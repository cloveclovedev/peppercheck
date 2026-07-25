import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_environment.g.dart';

enum AppEnvironment { dev, staging, production }

/// Build-time descriptor used by [appStartup] during bootstrap only.
/// Widget-facing runtime state lives in `appEnvironmentProvider`.
class AppConfig {
  final AppEnvironment environment;
  final String envFile;

  const AppConfig({required this.environment, required this.envFile});

  static const dev = AppConfig(
    environment: AppEnvironment.dev,
    envFile: 'assets/env/.env.dev',
  );

  static const staging = AppConfig(
    environment: AppEnvironment.staging,
    envFile: 'assets/env/.env.staging',
  );

  static const production = AppConfig(
    environment: AppEnvironment.production,
    envFile: 'assets/env/.env.production',
  );
}

@Riverpod(keepAlive: true)
AppEnvironment appEnvironment(Ref ref) => throw UnimplementedError(
  'appEnvironmentProvider must be overridden at the root ProviderContainer in appStartup. '
  'See peppercheck_flutter/lib/app/app_startup.dart.',
);

/// Resolves the Go API base URL for [env]. Dev goes through Caddy on :80
/// (the api is not host-published), so the host differs by emulator:
/// Android uses 10.0.2.2, the iOS simulator uses 127.0.0.1. Cleartext HTTP is
/// permitted for dev only (see the Android network-security config and iOS ATS
/// exception). Staging/production are HTTPS with no exception.
String resolveApiBaseUrl(AppEnvironment env, {required bool isAndroid}) {
  return switch (env) {
    AppEnvironment.dev => isAndroid ? 'http://10.0.2.2' : 'http://127.0.0.1',
    AppEnvironment.staging => 'https://staging.peppercheck.dev',
    AppEnvironment.production => 'https://peppercheck.dev',
  };
}

extension AppConfigApiBaseUrl on AppConfig {
  /// The Go API base URL for this config's environment on the current platform.
  String get apiBaseUrl =>
      resolveApiBaseUrl(environment, isAndroid: Platform.isAndroid);
}
