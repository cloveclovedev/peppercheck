// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_summary_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PaymentSummaryController)
const paymentSummaryControllerProvider = PaymentSummaryControllerProvider._();

final class PaymentSummaryControllerProvider
    extends $AsyncNotifierProvider<PaymentSummaryController, PaymentSummary> {
  const PaymentSummaryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentSummaryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentSummaryControllerHash();

  @$internal
  @override
  PaymentSummaryController create() => PaymentSummaryController();
}

String _$paymentSummaryControllerHash() =>
    r'969b3eb7c471b156ce78963e89c5a44c4c3d124a';

abstract class _$PaymentSummaryController
    extends $AsyncNotifier<PaymentSummary> {
  FutureOr<PaymentSummary> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<PaymentSummary>, PaymentSummary>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PaymentSummary>, PaymentSummary>,
              AsyncValue<PaymentSummary>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
