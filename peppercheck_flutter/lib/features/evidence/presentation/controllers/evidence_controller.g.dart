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
    extends
        $AsyncNotifierProvider<EvidenceController, EvidenceSubmissionState> {
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
    r'7327a354279e88133524d454fb71a6220a3e8b41';

abstract class _$EvidenceController
    extends $AsyncNotifier<EvidenceSubmissionState> {
  FutureOr<EvidenceSubmissionState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<EvidenceSubmissionState>,
              EvidenceSubmissionState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<EvidenceSubmissionState>,
                EvidenceSubmissionState
              >,
              AsyncValue<EvidenceSubmissionState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
