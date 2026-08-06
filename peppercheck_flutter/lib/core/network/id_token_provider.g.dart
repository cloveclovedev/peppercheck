// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_token_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Default: no token. Replaced by the Firebase implementation at composition.

@ProviderFor(idTokenProvider)
const idTokenProviderProvider = IdTokenProviderProvider._();

/// Default: no token. Replaced by the Firebase implementation at composition.

final class IdTokenProviderProvider
    extends
        $FunctionalProvider<IdTokenProvider, IdTokenProvider, IdTokenProvider>
    with $Provider<IdTokenProvider> {
  /// Default: no token. Replaced by the Firebase implementation at composition.
  const IdTokenProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'idTokenProviderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$idTokenProviderHash();

  @$internal
  @override
  $ProviderElement<IdTokenProvider> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IdTokenProvider create(Ref ref) {
    return idTokenProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdTokenProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdTokenProvider>(value),
    );
  }
}

String _$idTokenProviderHash() => r'77c2bc58348bd7c220c4f6d70fdf41294b11e94b';
