// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EvidenceController)
const evidenceControllerProvider = EvidenceControllerProvider._();

final class EvidenceControllerProvider
    extends $AsyncNotifierProvider<EvidenceController, void> {
  const EvidenceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'evidenceControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$evidenceControllerHash();

  @$internal
  @override
  EvidenceController create() => EvidenceController();
}

String _$evidenceControllerHash() =>
    r'c1d209f1f04b6ff2e6a3a600baf8612f44129536';

abstract class _$EvidenceController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
