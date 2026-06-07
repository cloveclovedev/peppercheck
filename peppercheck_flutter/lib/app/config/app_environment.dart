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
