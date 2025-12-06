enum AppEnvironment { debug, staging, production }

class AppConfig {
  final AppEnvironment environment;
  final String envFile;

  const AppConfig({required this.environment, required this.envFile});

  static const debug = AppConfig(
    environment: AppEnvironment.debug,
    envFile: 'assets/env/.env.debug',
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
