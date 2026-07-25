// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_in_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the login screen. Google in Phase 2 P2-5; Apple added in P2-6.

@ProviderFor(SignInViewModel)
const signInViewModelProvider = SignInViewModelProvider._();

/// Drives the login screen. Google in Phase 2 P2-5; Apple added in P2-6.
final class SignInViewModelProvider
    extends $AsyncNotifierProvider<SignInViewModel, void> {
  /// Drives the login screen. Google in Phase 2 P2-5; Apple added in P2-6.
  const SignInViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signInViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signInViewModelHash();

  @$internal
  @override
  SignInViewModel create() => SignInViewModel();
}

String _$signInViewModelHash() => r'736ff24719fe348dd4c5446066392fd5566f742e';

/// Drives the login screen. Google in Phase 2 P2-5; Apple added in P2-6.

abstract class _$SignInViewModel extends $AsyncNotifier<void> {
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
