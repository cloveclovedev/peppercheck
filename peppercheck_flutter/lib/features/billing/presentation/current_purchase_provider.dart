import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_purchase_provider.g.dart';

@Riverpod(keepAlive: true)
class CurrentPurchase extends _$CurrentPurchase {
  @override
  GooglePlayPurchaseDetails? build() => null;

  void set(GooglePlayPurchaseDetails purchase) => state = purchase;

  void clear() => state = null;
}
