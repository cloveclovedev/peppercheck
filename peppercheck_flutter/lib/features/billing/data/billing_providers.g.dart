// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(subscription)
const subscriptionProvider = SubscriptionProvider._();

final class SubscriptionProvider
    extends
        $FunctionalProvider<
          AsyncValue<Subscription?>,
          Subscription?,
          FutureOr<Subscription?>
        >
    with $FutureModifier<Subscription?>, $FutureProvider<Subscription?> {
  const SubscriptionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionHash();

  @$internal
  @override
  $FutureProviderElement<Subscription?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Subscription?> create(Ref ref) {
    return subscription(ref);
  }
}

String _$subscriptionHash() => r'9f46b1043db220c3e186d6c05799e780b336734a';

@ProviderFor(pointWallet)
const pointWalletProvider = PointWalletProvider._();

final class PointWalletProvider
    extends
        $FunctionalProvider<
          AsyncValue<PointWallet>,
          PointWallet,
          FutureOr<PointWallet>
        >
    with $FutureModifier<PointWallet>, $FutureProvider<PointWallet> {
  const PointWalletProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pointWalletProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pointWalletHash();

  @$internal
  @override
  $FutureProviderElement<PointWallet> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PointWallet> create(Ref ref) {
    return pointWallet(ref);
  }
}

String _$pointWalletHash() => r'86d74776e64c0064ed00d5a3a5cc6b59bb85ecaf';
