import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'in_app_purchase_repository.g.dart';

@Riverpod(keepAlive: true)
InAppPurchaseRepository inAppPurchaseRepository(Ref ref) {
  return InAppPurchaseRepository(InAppPurchase.instance);
}

class InAppPurchaseRepository {
  final InAppPurchase _iap;
  final _logger = Logger();

  InAppPurchaseRepository(this._iap);

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<void> buySubscription({
    required ProductDetails product,
    required String userId,
    GooglePlayPurchaseDetails? oldPurchase,
    bool isUpgrade = false,
  }) async {
    late PurchaseParam purchaseParam;

    if (Platform.isAndroid && oldPurchase != null) {
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: userId,
        changeSubscriptionParam: ChangeSubscriptionParam(
          oldPurchaseDetails: oldPurchase,
          replacementMode: isUpgrade
              ? ReplacementMode.chargeProratedPrice
              : ReplacementMode.deferred,
        ),
      );
    } else {
      purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: userId,
      );
    }

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
    await _iap.completePurchase(purchase);
  }

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

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
