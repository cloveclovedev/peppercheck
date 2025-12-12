// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'in_app_purchase_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(inAppPurchaseRepository)
const inAppPurchaseRepositoryProvider = InAppPurchaseRepositoryProvider._();

final class InAppPurchaseRepositoryProvider
    extends
        $FunctionalProvider<
          InAppPurchaseRepository,
          InAppPurchaseRepository,
          InAppPurchaseRepository
        >
    with $Provider<InAppPurchaseRepository> {
  const InAppPurchaseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inAppPurchaseRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inAppPurchaseRepositoryHash();

  @$internal
  @override
  $ProviderElement<InAppPurchaseRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InAppPurchaseRepository create(Ref ref) {
    return inAppPurchaseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InAppPurchaseRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InAppPurchaseRepository>(value),
    );
  }
}

String _$inAppPurchaseRepositoryHash() =>
    r'215eadf0425ef48f7eb02de708b106df4b25f3e7';
