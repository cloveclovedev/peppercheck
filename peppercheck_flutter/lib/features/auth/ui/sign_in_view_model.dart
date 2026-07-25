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
}
