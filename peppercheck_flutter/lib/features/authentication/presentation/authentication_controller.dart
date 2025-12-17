import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/authentication/data/authentication_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'authentication_controller.g.dart';

@riverpod
class AuthenticationController extends _$AuthenticationController {
  @override
  FutureOr<void> build() {
    // nothing to do
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authenticationRepositoryProvider).signInWithGoogle();
    });
    if (state.hasError) {
      ref
          .read(loggerProvider)
          .e('Sign-in error', error: state.error, stackTrace: state.stackTrace);
    }
  }
}
