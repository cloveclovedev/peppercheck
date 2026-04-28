// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'username_edit_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UsernameEditController)
const usernameEditControllerProvider = UsernameEditControllerProvider._();

final class UsernameEditControllerProvider
    extends $AsyncNotifierProvider<UsernameEditController, void> {
  const UsernameEditControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usernameEditControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usernameEditControllerHash();

  @$internal
  @override
  UsernameEditController create() => UsernameEditController();
}

String _$usernameEditControllerHash() =>
    r'3edb860752bcf770d4d102a13fdf58689f4d5152';

abstract class _$UsernameEditController extends $AsyncNotifier<void> {
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
