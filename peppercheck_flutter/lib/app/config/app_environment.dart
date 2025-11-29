enum AppEnvironment { debug, staging, production }

class AppConfig {
  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  static const debug = AppConfig(
    environment: AppEnvironment.debug,
    supabaseUrl: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://127.0.0.1:54321',
    ),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static const staging = AppConfig(
    environment: AppEnvironment.staging,
    supabaseUrl: 'YOUR_STAGING_SUPABASE_URL',
    supabaseAnonKey: 'YOUR_STAGING_SUPABASE_ANON_KEY',
  );

  static const production = AppConfig(
    environment: AppEnvironment.production,
    supabaseUrl: 'YOUR_PRODUCTION_SUPABASE_URL',
    supabaseAnonKey: 'YOUR_PRODUCTION_SUPABASE_ANON_KEY',
  );
}
