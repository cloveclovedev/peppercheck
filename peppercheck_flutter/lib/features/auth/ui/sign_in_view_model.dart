import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/auth_repository.dart';

part 'sign_in_view_model.g.dart';

/// Drives the login screen. Google in Phase 2 P2-5; Apple added in P2-6.
@riverpod
class SignInViewModel extends _$SignInViewModel {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  /// May leave [state] as `AsyncError` carrying `AccountLinkRequiredException`
  /// — the screen renders that as a link-consent dialog rather than a plain
  /// error message.
  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
  }

  /// Confirms the link-consent dialog: re-authenticates with the existing
  /// provider (Google — the only other provider in Phase 2) to obtain a fresh
  /// credential, then links the pending Apple credential onto that account.
  /// Call only after explicit user consent.
  Future<void> confirmAppleLink(AuthCredential pending) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final existing = await repo.googleCredential();
      await repo.linkAppleToExisting(pending: pending, existing: existing);
    });
  }

  /// Declines the link-consent dialog. Never links; simply returns to the
  /// sign-in state so the screen can show the cancellation message.
  void cancelAppleLink() {
    state = const AsyncData(null);
  }
}
