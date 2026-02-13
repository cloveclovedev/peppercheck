// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'judgement_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(judgementRepository)
const judgementRepositoryProvider = JudgementRepositoryProvider._();

final class JudgementRepositoryProvider
    extends
        $FunctionalProvider<
          JudgementRepository,
          JudgementRepository,
          JudgementRepository
        >
    with $Provider<JudgementRepository> {
  const JudgementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'judgementRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$judgementRepositoryHash();

  @$internal
  @override
  $ProviderElement<JudgementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  JudgementRepository create(Ref ref) {
    return judgementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JudgementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JudgementRepository>(value),
    );
  }
}

String _$judgementRepositoryHash() =>
    r'71b07e91e3b4192a6d1ea1d5820ab78c0b5c0045';
