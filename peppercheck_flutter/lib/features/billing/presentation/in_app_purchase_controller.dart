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
  RealtimeChannel? _realtimeChannel;

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
      _removeRealtimeSubscription();
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

      // Subscribe to Realtime BEFORE initiating purchase to avoid race condition.
      // The RTDN chain (Google → Pub/Sub → Edge Function → DB) can complete
      // before a post-purchase subscribe, causing us to miss the update.
      _subscribeToRealtimeUpdates();

      await repo.buySubscription(
        product: product,
        userId: userId,
        oldPurchase: oldPurchase,
        isUpgrade: isUpgrade,
      );
    } catch (e, st) {
      _removeRealtimeSubscription();
      state = AsyncError(e, st);
    }
  }

  Future<void> restorePurchases() async {
    try {
      final repo = ref.read(inAppPurchaseRepositoryProvider);
      _subscribeToRealtimeUpdates();
      await repo.restorePurchases();
    } catch (e, st) {
      _removeRealtimeSubscription();
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
        _removeRealtimeSubscription();
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
          // Signal UI to show "プラン更新中..." inline text.
          // Realtime subscription is already active (set up in buy()).
          state = const AsyncData(true);
        } catch (e, st) {
          _logger.e('Purchase completion failed', error: e, stackTrace: st);
          _removeRealtimeSubscription();
          state = AsyncError(e, st);
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        _removeRealtimeSubscription();
        state = const AsyncData(false);
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
            state = const AsyncData(false);
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
