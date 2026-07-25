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
  final baseUrl = resolveApiBaseUrl(env, isAndroid: Platform.isAndroid);
  final tokens = ref.watch(idTokenProviderProvider);
  return ApiClient(baseUrl: baseUrl, idTokenProvider: tokens);
}
