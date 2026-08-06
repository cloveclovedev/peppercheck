// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The server-owned matching config, fetched once per app run. Kept alive
/// because several screens (the publish referee-count selector, the referee
/// withdraw cutoff) read it and it changes only on a server deploy.

@ProviderFor(matchingConfig)
const matchingConfigProvider = MatchingConfigProvider._();

/// The server-owned matching config, fetched once per app run. Kept alive
/// because several screens (the publish referee-count selector, the referee
/// withdraw cutoff) read it and it changes only on a server deploy.

final class MatchingConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<MatchingConfig>,
          MatchingConfig,
          FutureOr<MatchingConfig>
        >
    with $FutureModifier<MatchingConfig>, $FutureProvider<MatchingConfig> {
  /// The server-owned matching config, fetched once per app run. Kept alive
  /// because several screens (the publish referee-count selector, the referee
  /// withdraw cutoff) read it and it changes only on a server deploy.
  const MatchingConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchingConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchingConfigHash();

  @$internal
  @override
  $FutureProviderElement<MatchingConfig> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MatchingConfig> create(Ref ref) {
    return matchingConfig(ref);
  }
}

String _$matchingConfigHash() => r'0fcb41f60efc8bd68bcc209450a2f01f39f319fe';
