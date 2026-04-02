// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_purchase_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrentPurchase)
const currentPurchaseProvider = CurrentPurchaseProvider._();

final class CurrentPurchaseProvider
    extends $NotifierProvider<CurrentPurchase, GooglePlayPurchaseDetails?> {
  const CurrentPurchaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPurchaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPurchaseHash();

  @$internal
  @override
  CurrentPurchase create() => CurrentPurchase();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GooglePlayPurchaseDetails? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GooglePlayPurchaseDetails?>(value),
    );
  }
}

String _$currentPurchaseHash() => r'3a8a770affb6e4ac6d518667396b827b3b2dabf1';

abstract class _$CurrentPurchase extends $Notifier<GooglePlayPurchaseDetails?> {
  GooglePlayPurchaseDetails? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<GooglePlayPurchaseDetails?, GooglePlayPurchaseDetails?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                GooglePlayPurchaseDetails?,
                GooglePlayPurchaseDetails?
              >,
              GooglePlayPurchaseDetails?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
