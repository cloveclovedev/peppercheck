// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app-wide [ApiClient]. Base URL comes from the build environment; the
/// bearer token comes from [idTokenProvider] (overridden by `features/auth`).

@ProviderFor(apiClient)
const apiClientProvider = ApiClientProvider._();

/// The app-wide [ApiClient]. Base URL comes from the build environment; the
/// bearer token comes from [idTokenProvider] (overridden by `features/auth`).

final class ApiClientProvider
    extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  /// The app-wide [ApiClient]. Base URL comes from the build environment; the
  /// bearer token comes from [idTokenProvider] (overridden by `features/auth`).
  const ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientHash() => r'788d3c5d5c482336a1a361e0ac3313ac91c7cdb4';
