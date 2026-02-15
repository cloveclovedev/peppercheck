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
    r'24411392215624b1fcd8a47fe04bdcd41ef0e9c5';

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
