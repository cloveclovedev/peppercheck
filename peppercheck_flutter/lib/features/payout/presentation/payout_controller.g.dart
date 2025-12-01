// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PayoutController)
const payoutControllerProvider = PayoutControllerProvider._();

final class PayoutControllerProvider
    extends $AsyncNotifierProvider<PayoutController, PayoutSetupStatus> {
  const PayoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'payoutControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$payoutControllerHash();

  @$internal
  @override
  PayoutController create() => PayoutController();
}

String _$payoutControllerHash() => r'0fc4c89733d820b380bf0cf5d05bd1db62ca420f';

abstract class _$PayoutController extends $AsyncNotifier<PayoutSetupStatus> {
  FutureOr<PayoutSetupStatus> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<PayoutSetupStatus>, PayoutSetupStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PayoutSetupStatus>, PayoutSetupStatus>,
              AsyncValue<PayoutSetupStatus>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
