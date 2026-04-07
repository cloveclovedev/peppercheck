import 'package:peppercheck_flutter/features/billing/data/billing_repository.dart';
import 'package:peppercheck_flutter/features/billing/domain/point_wallet.dart';
import 'package:peppercheck_flutter/features/billing/domain/subscription.dart';
import 'package:peppercheck_flutter/features/billing/domain/trial_point_wallet.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'billing_providers.g.dart';

@riverpod
FutureOr<Subscription?> subscription(Ref ref) {
  return ref.read(billingRepositoryProvider).fetchSubscription();
}

@riverpod
FutureOr<PointWallet> pointWallet(Ref ref) {
  return ref.read(billingRepositoryProvider).fetchPointWallet();
}

@riverpod
FutureOr<TrialPointWallet?> trialPointWallet(Ref ref) {
  return ref.read(billingRepositoryProvider).fetchTrialPointWallet();
}

@riverpod
FutureOr<int> matchingStrategyCost(Ref ref, String strategy) {
  return ref
      .read(billingRepositoryProvider)
      .fetchMatchingStrategyCost(strategy);
}
