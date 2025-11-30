// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BillingController)
const billingControllerProvider = BillingControllerProvider._();

final class BillingControllerProvider
    extends $AsyncNotifierProvider<BillingController, DefaultBillingMethod?> {
  const BillingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billingControllerHash();

  @$internal
  @override
  BillingController create() => BillingController();
}

String _$billingControllerHash() => r'3529581cd6235cc42e1c05956b109d2bfdf6bfe9';

abstract class _$BillingController
    extends $AsyncNotifier<DefaultBillingMethod?> {
  FutureOr<DefaultBillingMethod?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<DefaultBillingMethod?>, DefaultBillingMethod?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DefaultBillingMethod?>,
                DefaultBillingMethod?
              >,
              AsyncValue<DefaultBillingMethod?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
