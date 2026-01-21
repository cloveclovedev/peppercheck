// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(evidenceRepository)
const evidenceRepositoryProvider = EvidenceRepositoryProvider._();

final class EvidenceRepositoryProvider
    extends
        $FunctionalProvider<
          EvidenceRepository,
          EvidenceRepository,
          EvidenceRepository
        >
    with $Provider<EvidenceRepository> {
  const EvidenceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'evidenceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$evidenceRepositoryHash();

  @$internal
  @override
  $ProviderElement<EvidenceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EvidenceRepository create(Ref ref) {
    return evidenceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EvidenceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EvidenceRepository>(value),
    );
  }
}

String _$evidenceRepositoryHash() =>
    r'e23e810cf435827cda48decdf15e361ef9f875a8';
