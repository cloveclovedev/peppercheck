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

@ProviderFor(trialPointWallet)
const trialPointWalletProvider = TrialPointWalletProvider._();

final class TrialPointWalletProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrialPointWallet?>,
          TrialPointWallet?,
          FutureOr<TrialPointWallet?>
        >
    with
        $FutureModifier<TrialPointWallet?>,
        $FutureProvider<TrialPointWallet?> {
  const TrialPointWalletProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trialPointWalletProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trialPointWalletHash();

  @$internal
  @override
  $FutureProviderElement<TrialPointWallet?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrialPointWallet?> create(Ref ref) {
    return trialPointWallet(ref);
  }
}

String _$trialPointWalletHash() => r'294173bcadda2f6b14342f18757fd764e4026e2a';

@ProviderFor(matchingStrategyCost)
const matchingStrategyCostProvider = MatchingStrategyCostFamily._();

final class MatchingStrategyCostProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  const MatchingStrategyCostProvider._({
    required MatchingStrategyCostFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'matchingStrategyCostProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$matchingStrategyCostHash();

  @override
  String toString() {
    return r'matchingStrategyCostProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return matchingStrategyCost(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MatchingStrategyCostProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$matchingStrategyCostHash() =>
    r'09c8a49dc86d1d3a6a334a2aebbf21b4b30106fd';

final class MatchingStrategyCostFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  const MatchingStrategyCostFamily._()
    : super(
        retry: null,
        name: r'matchingStrategyCostProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MatchingStrategyCostProvider call(String strategy) =>
      MatchingStrategyCostProvider._(argument: strategy, from: this);

  @override
  String toString() => r'matchingStrategyCostProvider';
}
