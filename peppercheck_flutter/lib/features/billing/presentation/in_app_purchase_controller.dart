import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/data/in_app_purchase_repository.dart';
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
  RealtimeChannel? _realtimeChannel;

  @override
  FutureOr<void> build() {
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
      _removeRealtimeSubscription();
    });
  }

  Future<void> buy({
    required ProductDetails product,
    GooglePlayPurchaseDetails? oldPurchase,
    bool isUpgrade = false,
  }) async {
    state = const AsyncLoading();
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
    state = const AsyncLoading();
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      await repo.restorePurchases();
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
        state = const AsyncLoading();
      } else if (purchase.status == PurchaseStatus.error) {
        _logger.e('Purchase Error: ${purchase.error}');
        state = AsyncError(purchase.error!, StackTrace.current);
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          if (purchase.pendingCompletePurchase) {
            await repo.completePurchase(purchase);
          }
          _subscribeToRealtimeUpdates();
        } catch (e, st) {
          _logger.e('Purchase completion failed', error: e, stackTrace: st);
          state = AsyncError(e, st);
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        state = const AsyncData(null);
      }
    }
  }

  void _subscribeToRealtimeUpdates() {
    _removeRealtimeSubscription();

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('iap-subscription-status')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _logger.i(
              'Subscription updated via Realtime: ${payload.newRecord}',
            );
            ref.invalidate(subscriptionProvider);
            ref.invalidate(pointWalletProvider);
            state = const AsyncData(null);
            _removeRealtimeSubscription();
          },
        )
        .subscribe();
  }

  void _removeRealtimeSubscription() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }
}
