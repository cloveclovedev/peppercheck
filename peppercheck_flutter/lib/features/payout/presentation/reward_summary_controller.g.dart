// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_summary_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RewardSummaryController)
const rewardSummaryControllerProvider = RewardSummaryControllerProvider._();

final class RewardSummaryControllerProvider
    extends
        $AsyncNotifierProvider<RewardSummaryController, RewardSummaryState> {
  const RewardSummaryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rewardSummaryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rewardSummaryControllerHash();

  @$internal
  @override
  RewardSummaryController create() => RewardSummaryController();
}

String _$rewardSummaryControllerHash() =>
    r'2d17861c366739b068a937cde4a8ef041bad564a';

abstract class _$RewardSummaryController
    extends $AsyncNotifier<RewardSummaryState> {
  FutureOr<RewardSummaryState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<RewardSummaryState>, RewardSummaryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RewardSummaryState>, RewardSummaryState>,
              AsyncValue<RewardSummaryState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
