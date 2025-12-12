import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/data/in_app_purchase_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'in_app_purchase_controller.g.dart';

@riverpod
Future<List<ProductDetails>> availableProducts(Ref ref) async {
  // TODO: Define these IDs somewhere (remote config or const)
  // For now hardcoding based on pricing.adoc
  const productIds = <String>{
    'light_monthly', // These must match Play Console Product IDs
    'standard_monthly',
    'premium_monthly',
  };

  final repo = ref.watch(inAppPurchaseRepositoryProvider);
  if (!await repo.isAvailable()) {
    return [];
  }
  return repo.fetchProducts(productIds);
}

@Riverpod(keepAlive: true)
class InAppPurchaseController extends _$InAppPurchaseController {
  final _logger = Logger();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  FutureOr<void> build() {
    // Start listening on build
    final repo = ref.watch(inAppPurchaseRepositoryProvider);
    _subscription = repo.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );

    ref.onDispose(() {
      _subscription?.cancel();
    });
  }

  Future<void> buy(ProductDetails product) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      await repo.buySubscription(product);
      // State remains loading or idle?
      // actual result comes via stream.
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    final repo = ref.read(inAppPurchaseRepositoryProvider);

    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        state = const AsyncLoading(); // Show loading overlay
      } else {
        if (purchase.status == PurchaseStatus.error) {
          _logger.e('Purchase Error: ${purchase.error}');
          state = AsyncError(purchase.error!, StackTrace.current);
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          try {
            // 1. Verify with Backend
            await repo.verifyPurchase(purchase);

            // 2. Complete/Acknowledge
            if (purchase.pendingCompletePurchase) {
              await repo.completePurchase(purchase);
            }

            // 3. Refresh Subscription Status
            ref.invalidate(subscriptionProvider);
            ref.invalidate(pointWalletProvider);

            state = const AsyncData(null);
          } catch (e, st) {
            _logger.e(
              'Verification/Completion Failed',
              error: e,
              stackTrace: st,
            );
            state = AsyncError(e, st);
          }
        }
      }
    }
  }
}
