import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/config/app_environment.dart';
import 'api_client.dart';
import 'id_token_provider.dart';

part 'api_client_provider.g.dart';

/// The app-wide [ApiClient]. Base URL comes from the build environment; the
/// bearer token comes from [idTokenProvider] (overridden by `features/auth`).
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final env = ref.watch(appEnvironmentProvider);
  // Dev-only override of the Caddy host port (passed by scripts/dev-run.sh as
  // --dart-define=DEV_API_PORT when it moves the port to avoid a clash).
  const devPort = int.fromEnvironment('DEV_API_PORT', defaultValue: 80);
  final baseUrl = resolveApiBaseUrl(
    env,
    isAndroid: Platform.isAndroid,
    devPort: devPort,
  );
  final tokens = ref.watch(idTokenProviderProvider);
  return ApiClient(baseUrl: baseUrl, idTokenProvider: tokens);
}
