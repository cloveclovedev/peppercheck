// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReportController)
const reportControllerProvider = ReportControllerProvider._();

final class ReportControllerProvider
    extends $AsyncNotifierProvider<ReportController, void> {
  const ReportControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportControllerHash();

  @$internal
  @override
  ReportController create() => ReportController();
}

String _$reportControllerHash() => r'6b5a8ffbdcf67cce197b63c5816cf756de7c0b9d';

abstract class _$ReportController extends $AsyncNotifier<void> {
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

@ProviderFor(hasReported)
const hasReportedProvider = HasReportedFamily._();

final class HasReportedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  const HasReportedProvider._({
    required HasReportedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'hasReportedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hasReportedHash();

  @override
  String toString() {
    return r'hasReportedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return hasReported(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HasReportedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hasReportedHash() => r'289f25adcfe52493faa10c7e609df748071e4f42';

final class HasReportedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const HasReportedFamily._()
    : super(
        retry: null,
        name: r'hasReportedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HasReportedProvider call(String taskId) =>
      HasReportedProvider._(argument: taskId, from: this);

  @override
  String toString() => r'hasReportedProvider';
}
