// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(billingRepository)
const billingRepositoryProvider = BillingRepositoryProvider._();

final class BillingRepositoryProvider
    extends
        $FunctionalProvider<
          BillingRepository,
          BillingRepository,
          BillingRepository
        >
    with $Provider<BillingRepository> {
  const BillingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billingRepositoryHash();

  @$internal
  @override
  $ProviderElement<BillingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BillingRepository create(Ref ref) {
    return billingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BillingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BillingRepository>(value),
    );
  }
}

String _$billingRepositoryHash() => r'053865fba96556f2d77a92988716b6ca297919fe';
