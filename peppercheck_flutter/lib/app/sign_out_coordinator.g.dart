// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_coordinator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(signOutCoordinator)
const signOutCoordinatorProvider = SignOutCoordinatorProvider._();

final class SignOutCoordinatorProvider
    extends
        $FunctionalProvider<
          SignOutCoordinator,
          SignOutCoordinator,
          SignOutCoordinator
        >
    with $Provider<SignOutCoordinator> {
  const SignOutCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signOutCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signOutCoordinatorHash();

  @$internal
  @override
  $ProviderElement<SignOutCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SignOutCoordinator create(Ref ref) {
    return signOutCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignOutCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignOutCoordinator>(value),
    );
  }
}

String _$signOutCoordinatorHash() =>
    r'efa0b9c540473d95e7ebe0ad3c2188f8748c6e9b';
