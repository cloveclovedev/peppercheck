import 'package:peppercheck_flutter/features/billing/data/billing_repository.dart';
import 'package:peppercheck_flutter/features/billing/domain/point_wallet.dart';
import 'package:peppercheck_flutter/features/billing/domain/subscription.dart';
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
