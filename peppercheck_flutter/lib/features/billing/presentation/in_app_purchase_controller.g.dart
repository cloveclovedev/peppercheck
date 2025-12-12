// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'in_app_purchase_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(availableProducts)
const availableProductsProvider = AvailableProductsProvider._();

final class AvailableProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProductDetails>>,
          List<ProductDetails>,
          FutureOr<List<ProductDetails>>
        >
    with
        $FutureModifier<List<ProductDetails>>,
        $FutureProvider<List<ProductDetails>> {
  const AvailableProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availableProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availableProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<ProductDetails>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProductDetails>> create(Ref ref) {
    return availableProducts(ref);
  }
}

String _$availableProductsHash() => r'06c3364324f2de5e15c16a43fd427742e6373d3f';

@ProviderFor(InAppPurchaseController)
const inAppPurchaseControllerProvider = InAppPurchaseControllerProvider._();

final class InAppPurchaseControllerProvider
    extends $AsyncNotifierProvider<InAppPurchaseController, void> {
  const InAppPurchaseControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inAppPurchaseControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inAppPurchaseControllerHash();

  @$internal
  @override
  InAppPurchaseController create() => InAppPurchaseController();
}

String _$inAppPurchaseControllerHash() =>
    r'9fafcda3f86cbb916f2022b19d2dca4652e6824b';

abstract class _$InAppPurchaseController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
