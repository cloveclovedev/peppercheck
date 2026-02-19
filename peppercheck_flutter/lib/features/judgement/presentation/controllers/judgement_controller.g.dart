// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'judgement_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(JudgementController)
const judgementControllerProvider = JudgementControllerProvider._();

final class JudgementControllerProvider
    extends $AsyncNotifierProvider<JudgementController, void> {
  const JudgementControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'judgementControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$judgementControllerHash();

  @$internal
  @override
  JudgementController create() => JudgementController();
}

String _$judgementControllerHash() =>
    r'216332e123a2508564a40cf9b623fcad5371796a';

abstract class _$JudgementController extends $AsyncNotifier<void> {
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
