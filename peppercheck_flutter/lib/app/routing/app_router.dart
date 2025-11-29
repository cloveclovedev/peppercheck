import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_screen.dart';
import 'package:peppercheck_flutter/features/authentication/presentation/login_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
  ],
);
