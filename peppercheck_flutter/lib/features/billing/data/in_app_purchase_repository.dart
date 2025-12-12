import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'in_app_purchase_repository.g.dart';

@Riverpod(keepAlive: true)
InAppPurchaseRepository inAppPurchaseRepository(Ref ref) {
  return InAppPurchaseRepository(
    InAppPurchase.instance,
    Supabase.instance.client,
  );
}

class InAppPurchaseRepository {
  final InAppPurchase _iap;
  final SupabaseClient _supabase;
  final _logger = Logger();

  InAppPurchaseRepository(this._iap, this._supabase);

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<void> buySubscription(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    if (Platform.isAndroid) {
      // Android specific: no special params needed for basic sub?
      // handling upgrades/downgrades would need GooglePlayPurchaseParam
    }

    // For subscription, use buyNonConsumable
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
    await _iap.completePurchase(purchase);
  }

  /// Verifies the purchase with the backend.
  /// Throws exception if verification fails.
  Future<void> verifyPurchase(PurchaseDetails purchase) async {
    try {
      if (purchase.pendingCompletePurchase) {
        // Only verify if we haven't completed it?
        // Logic: Verify first, then Complete (Acknowledge).
      }

      final verificationData = purchase.verificationData;

      // Determine source/provider
      final source = verificationData.source; // 'google_play' or 'app_store'

      if (source == 'google_play') {
        await _supabase.functions.invoke(
          'verify-google-purchase',
          body: {
            'productId': purchase.productID,
            'purchaseToken': verificationData
                .serverVerificationData, // Purchase Token for Google
            'type':
                'subscription', // TODO: Make dynamic if we support consumables
          },
        );
      } else {
        throw UnimplementedError('Verification for $source is not implemented');
      }
    } on FunctionException catch (e) {
      _logger.e('Backend Verification Failed: ${e.details}', error: e);
      throw 'Verification Failed: ${e.details}';
    } catch (e) {
      _logger.e('Verification Error', error: e);
      rethrow;
    }
  }

  // Fetch products from store
  Future<List<ProductDetails>> fetchProducts(Set<String> productIds) async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.notFoundIDs.isNotEmpty) {
      _logger.w('Products not found: ${response.notFoundIDs}');
    }
    if (response.error != null) {
      throw response.error!;
    }
    return response.productDetails;
  }
}
