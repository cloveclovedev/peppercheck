// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timezone_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TimezoneViewModel)
const timezoneViewModelProvider = TimezoneViewModelProvider._();

final class TimezoneViewModelProvider
    extends $AsyncNotifierProvider<TimezoneViewModel, void> {
  const TimezoneViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timezoneViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timezoneViewModelHash();

  @$internal
  @override
  TimezoneViewModel create() => TimezoneViewModel();
}

String _$timezoneViewModelHash() => r'f19aa273a86c3f50337b856a6bc6c989de281738';

abstract class _$TimezoneViewModel extends $AsyncNotifier<void> {
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
