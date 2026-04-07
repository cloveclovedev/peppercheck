// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_summary_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paymentSummaryRepository)
const paymentSummaryRepositoryProvider = PaymentSummaryRepositoryProvider._();

final class PaymentSummaryRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentSummaryRepository,
          PaymentSummaryRepository,
          PaymentSummaryRepository
        >
    with $Provider<PaymentSummaryRepository> {
  const PaymentSummaryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentSummaryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentSummaryRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentSummaryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentSummaryRepository create(Ref ref) {
    return paymentSummaryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentSummaryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentSummaryRepository>(value),
    );
  }
}

String _$paymentSummaryRepositoryHash() =>
    r'2420c65fe8011602194b86bc549553fa76a659ac';
