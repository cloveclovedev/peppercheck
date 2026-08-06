import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/ui/login_screen.dart';
import 'package:peppercheck_flutter/features/home/ui/home_screen.dart';
import 'package:peppercheck_flutter/features/payment_dashboard/presentation/payment_dashboard_screen.dart';
import 'package:peppercheck_flutter/features/profile/ui/profile_screen.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_creation_screen.dart';
import 'package:peppercheck_flutter/features/task/presentation/task_detail_screen.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final isLoggedIn = ref.watch(isFirebaseAuthenticatedProvider);
  final me = ref.watch(currentAppUserProvider);

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
      GoRoute(
        path: '/task_detail/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId']!;
          final task = state.extra as Task?;
          return TaskDetailScreen(taskId: taskId, initialTask: task);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == '/';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/';
      }

      // Firebase-authenticated: gate further navigation on `/me` resolving.
      // While loading, or if it errored, stay on '/' — the login screen shows
      // a loading indicator or a retry + sign-out affordance, never a
      // '/home' limbo.
      if (!me.hasValue) {
        return isLoggingIn ? null : '/';
      }

      if (isLoggingIn) {
        return '/home';
      }

      return null;
    },
  );
}
