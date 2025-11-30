// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stripe_billing_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(stripeBillingRepository)
const stripeBillingRepositoryProvider = StripeBillingRepositoryProvider._();

final class StripeBillingRepositoryProvider
    extends
        $FunctionalProvider<
          StripeBillingRepository,
          StripeBillingRepository,
          StripeBillingRepository
        >
    with $Provider<StripeBillingRepository> {
  const StripeBillingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stripeBillingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stripeBillingRepositoryHash();

  @$internal
  @override
  $ProviderElement<StripeBillingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StripeBillingRepository create(Ref ref) {
    return stripeBillingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StripeBillingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StripeBillingRepository>(value),
    );
  }
}

String _$stripeBillingRepositoryHash() =>
    r'382ae351eed0c2dc40c1ab6d0eb862a1bc39453d';
