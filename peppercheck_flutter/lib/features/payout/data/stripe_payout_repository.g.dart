// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stripe_payout_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(stripePayoutRepository)
const stripePayoutRepositoryProvider = StripePayoutRepositoryProvider._();

final class StripePayoutRepositoryProvider
    extends
        $FunctionalProvider<
          StripePayoutRepository,
          StripePayoutRepository,
          StripePayoutRepository
        >
    with $Provider<StripePayoutRepository> {
  const StripePayoutRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stripePayoutRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stripePayoutRepositoryHash();

  @$internal
  @override
  $ProviderElement<StripePayoutRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StripePayoutRepository create(Ref ref) {
    return stripePayoutRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StripePayoutRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StripePayoutRepository>(value),
    );
  }
}

String _$stripePayoutRepositoryHash() =>
    r'9de076ad2d2c6155f4b8bd6290044e55c6ce1185';
