import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/id_token_provider.dart';
import '../data/auth_repository.dart';
import '../data/me_repository.dart';
import '../domain/app_user.dart';

part 'auth_state.g.dart';

/// Firebase auth-state stream. The Firebase `User?` type is confined to this
/// feature — other features read [currentAppUser] instead.
@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(Ref ref) =>
    FirebaseAuth.instance.authStateChanges();

/// True while a Firebase user is present. Extracted so tests and the router can
/// branch without touching the Firebase `User` type.
@Riverpod(keepAlive: true)
bool isFirebaseAuthenticated(Ref ref) =>
    ref.watch(authStateChangesProvider).value != null;

/// The app-level current user. When Firebase-authenticated, resolves the
/// internal user via `GET /api/v1/me`; null when signed out. This is where the
/// internal UUID is exposed to the rest of the app (Phase 5 RevenueCat wiring).
@Riverpod(keepAlive: true)
Future<AppUser?> currentAppUser(Ref ref) async {
  if (!ref.watch(isFirebaseAuthenticatedProvider)) return null;
  return ref.watch(meRepositoryProvider).fetchMe();
}

/// Firebase-backed [IdTokenProvider]. Overrides the default (null) provider at
/// composition so `core/network` gets real bearer tokens without importing the
/// Firebase SDK.
IdTokenProvider firebaseIdTokenProvider(Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return ({required bool forceRefresh}) =>
      repo.idToken(forceRefresh: forceRefresh);
}
