// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Firebase auth-state stream. The Firebase `User?` type is confined to this
/// feature — other features read [currentAppUser] instead.

@ProviderFor(authStateChanges)
const authStateChangesProvider = AuthStateChangesProvider._();

/// Firebase auth-state stream. The Firebase `User?` type is confined to this
/// feature — other features read [currentAppUser] instead.

final class AuthStateChangesProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, Stream<User?>>
    with $FutureModifier<User?>, $StreamProvider<User?> {
  /// Firebase auth-state stream. The Firebase `User?` type is confined to this
  /// feature — other features read [currentAppUser] instead.
  const AuthStateChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateChangesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateChangesHash();

  @$internal
  @override
  $StreamProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<User?> create(Ref ref) {
    return authStateChanges(ref);
  }
}

String _$authStateChangesHash() => r'280cefd66d44083e4d6c3a3b7d5d3e8dfad52c23';

/// True while a Firebase user is present. Extracted so tests and the router can
/// branch without touching the Firebase `User` type.

@ProviderFor(isFirebaseAuthenticated)
const isFirebaseAuthenticatedProvider = IsFirebaseAuthenticatedProvider._();

/// True while a Firebase user is present. Extracted so tests and the router can
/// branch without touching the Firebase `User` type.

final class IsFirebaseAuthenticatedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True while a Firebase user is present. Extracted so tests and the router can
  /// branch without touching the Firebase `User` type.
  const IsFirebaseAuthenticatedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isFirebaseAuthenticatedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isFirebaseAuthenticatedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isFirebaseAuthenticated(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isFirebaseAuthenticatedHash() =>
    r'23dfa16db77db0066771d1d579538a9b394bc41e';

/// The app-level current user. When Firebase-authenticated, resolves the
/// internal user via `GET /api/v1/me`; null when signed out. This is where the
/// internal UUID is exposed to the rest of the app (Phase 5 RevenueCat wiring).

@ProviderFor(currentAppUser)
const currentAppUserProvider = CurrentAppUserProvider._();

/// The app-level current user. When Firebase-authenticated, resolves the
/// internal user via `GET /api/v1/me`; null when signed out. This is where the
/// internal UUID is exposed to the rest of the app (Phase 5 RevenueCat wiring).

final class CurrentAppUserProvider
    extends
        $FunctionalProvider<AsyncValue<AppUser?>, AppUser?, FutureOr<AppUser?>>
    with $FutureModifier<AppUser?>, $FutureProvider<AppUser?> {
  /// The app-level current user. When Firebase-authenticated, resolves the
  /// internal user via `GET /api/v1/me`; null when signed out. This is where the
  /// internal UUID is exposed to the rest of the app (Phase 5 RevenueCat wiring).
  const CurrentAppUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAppUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAppUserHash();

  @$internal
  @override
  $FutureProviderElement<AppUser?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppUser?> create(Ref ref) {
    return currentAppUser(ref);
  }
}

String _$currentAppUserHash() => r'95c7202d7c2e54b5e11258015d2f968045a8aed0';
