import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/authentication/presentation/login_screen.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_screen.dart';
import 'package:peppercheck_flutter/features/payment_dashboard/presentation/payment_dashboard_screen.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_screen.dart';
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
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentDashboardScreen(),
      ),
      GoRoute(
        path: '/create_task',
        builder: (context, state) => const TaskCreationScreen(),
      ),
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
