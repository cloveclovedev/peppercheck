import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/data/in_app_purchase_repository.dart';
import 'package:peppercheck_flutter/features/billing/presentation/current_purchase_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'in_app_purchase_controller.g.dart';

@riverpod
Future<List<ProductDetails>> availableProducts(Ref ref) async {
  const productIds = <String>{
    'light_monthly',
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
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  FutureOr<bool> build() {
    final repo = ref.watch(inAppPurchaseRepositoryProvider);
    _purchaseSubscription = repo.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () {
        _purchaseSubscription?.cancel();
      },
      onError: (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );

    ref.onDispose(() {
      _purchaseSubscription?.cancel();
    });

    return false;
  }

  Future<void> buy({
    required ProductDetails product,
    GooglePlayPurchaseDetails? oldPurchase,
    bool isUpgrade = false,
  }) async {
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await repo.buySubscription(
        product: product,
        userId: userId,
        oldPurchase: oldPurchase,
        isUpgrade: isUpgrade,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> restorePurchases() async {
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      await repo.restorePurchases();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Fetches the current Google Play purchase for upgrade/downgrade flow.
  /// Unlike [restorePurchases], this does not set up Realtime subscription.
  Future<void> fetchCurrentPurchase() async {
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      await repo.restorePurchases();
    } catch (e, st) {
      _logger.e('Failed to fetch current purchase', error: e, stackTrace: st);
      // Non-fatal: plan change won't work but new purchase still will.
    }
  }

  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    final repo = ref.read(inAppPurchaseRepositoryProvider);

    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // No-op: Google Play dialog is visible, no need to change state.
      } else if (purchase.status == PurchaseStatus.error) {
        _logger.e('Purchase Error: ${purchase.error}');
        state = AsyncError(purchase.error!, StackTrace.current);
      } else if (purchase.status == PurchaseStatus.restored) {
        // Store restored Google Play purchase for upgrade/downgrade flow.
        // Do NOT change controller state — this is not a new purchase.
        if (purchase is GooglePlayPurchaseDetails) {
          ref.read(currentPurchaseProvider.notifier).set(purchase);
        }
        if (purchase.pendingCompletePurchase) {
          await repo.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.purchased) {
        try {
          if (purchase.pendingCompletePurchase) {
            await repo.completePurchase(purchase);
          }
          state = const AsyncData(false);
          _scheduleSubscriptionRefresh();
        } catch (e, st) {
          _logger.e('Purchase completion failed', error: e, stackTrace: st);
          state = AsyncError(e, st);
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        state = const AsyncData(false);
      }
    }
  }

  /// Polls the DB for subscription changes after a purchase completes.
  /// Fire-and-forget: does not block the caller.
  /// Uses progressive intervals (1s, 1s, 2s, 2s, 3s) for faster initial feedback.
  /// Stops early if data changes.
  Future<void> _scheduleSubscriptionRefresh() async {
    const delays = [1, 1, 2, 2, 3];
    final prevData = ref.read(subscriptionProvider).value;
    for (final seconds in delays) {
      await Future.delayed(Duration(seconds: seconds));
      ref.invalidate(subscriptionProvider);
      ref.invalidate(pointWalletProvider);
      try {
        final newData = await ref.read(subscriptionProvider.future);
        if (newData?.status != prevData?.status ||
            newData?.planId != prevData?.planId) {
          break;
        }
      } catch (e) {
        _logger.e('Subscription refresh failed', error: e);
        break;
      }
    }
  }
}
