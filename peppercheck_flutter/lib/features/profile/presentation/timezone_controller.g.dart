// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timezone_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TimezoneController)
const timezoneControllerProvider = TimezoneControllerProvider._();

final class TimezoneControllerProvider
    extends $AsyncNotifierProvider<TimezoneController, void> {
  const TimezoneControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timezoneControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timezoneControllerHash();

  @$internal
  @override
  TimezoneController create() => TimezoneController();
}

String _$timezoneControllerHash() =>
    r'b9f02f402c53c7a5f5f3e661886ffaa30656bac6';

abstract class _$TimezoneController extends $AsyncNotifier<void> {
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
