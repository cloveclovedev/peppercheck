// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_blocked_dates_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RefereeBlockedDatesController)
const refereeBlockedDatesControllerProvider =
    RefereeBlockedDatesControllerProvider._();

final class RefereeBlockedDatesControllerProvider
    extends
        $AsyncNotifierProvider<
          RefereeBlockedDatesController,
          List<RefereeBlockedDate>
        > {
  const RefereeBlockedDatesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refereeBlockedDatesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refereeBlockedDatesControllerHash();

  @$internal
  @override
  RefereeBlockedDatesController create() => RefereeBlockedDatesController();
}

String _$refereeBlockedDatesControllerHash() =>
    r'791eeea4e48c93da7c3fa2317157beb8f7ac4e5c';

abstract class _$RefereeBlockedDatesController
    extends $AsyncNotifier<List<RefereeBlockedDate>> {
  FutureOr<List<RefereeBlockedDate>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RefereeBlockedDate>>,
              List<RefereeBlockedDate>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RefereeBlockedDate>>,
                List<RefereeBlockedDate>
              >,
              AsyncValue<List<RefereeBlockedDate>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
