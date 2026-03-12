// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletion_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountDeletionController)
const accountDeletionControllerProvider = AccountDeletionControllerProvider._();

final class AccountDeletionControllerProvider
    extends
        $AsyncNotifierProvider<
          AccountDeletionController,
          AccountDeletableStatus
        > {
  const AccountDeletionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionControllerHash();

  @$internal
  @override
  AccountDeletionController create() => AccountDeletionController();
}

String _$accountDeletionControllerHash() =>
    r'a7fbe43fa89871699c27641be56eabc51eeb1595';

abstract class _$AccountDeletionController
    extends $AsyncNotifier<AccountDeletableStatus> {
  FutureOr<AccountDeletableStatus> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<AccountDeletableStatus>, AccountDeletableStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AccountDeletableStatus>,
                AccountDeletableStatus
              >,
              AsyncValue<AccountDeletableStatus>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
