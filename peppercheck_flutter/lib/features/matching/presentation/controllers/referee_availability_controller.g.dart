// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_availability_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RefereeAvailabilityController)
const refereeAvailabilityControllerProvider =
    RefereeAvailabilityControllerProvider._();

final class RefereeAvailabilityControllerProvider
    extends
        $AsyncNotifierProvider<
          RefereeAvailabilityController,
          List<RefereeAvailableTimeSlot>
        > {
  const RefereeAvailabilityControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refereeAvailabilityControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refereeAvailabilityControllerHash();

  @$internal
  @override
  RefereeAvailabilityController create() => RefereeAvailabilityController();
}

String _$refereeAvailabilityControllerHash() =>
    r'5bbfbd4be0275e10db1cdc93964f2a18cbb85d26';

abstract class _$RefereeAvailabilityController
    extends $AsyncNotifier<List<RefereeAvailableTimeSlot>> {
  FutureOr<List<RefereeAvailableTimeSlot>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RefereeAvailableTimeSlot>>,
              List<RefereeAvailableTimeSlot>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RefereeAvailableTimeSlot>>,
                List<RefereeAvailableTimeSlot>
              >,
              AsyncValue<List<RefereeAvailableTimeSlot>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
