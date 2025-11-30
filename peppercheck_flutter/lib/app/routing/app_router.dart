import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/authentication/presentation/login_screen.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isLoggingIn = state.uri.path == '/';

      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }

      if (!isLoggedIn && !isLoggingIn) {
        return '/';
      }

      return null;
    },
  );
}
