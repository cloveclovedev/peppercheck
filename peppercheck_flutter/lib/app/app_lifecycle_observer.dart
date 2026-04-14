import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';

/// Refreshes stale provider data when the app returns to the foreground.
///
/// Place this widget near the top of the widget tree (inside ProviderScope).
/// Guards: skips invalidation when unauthenticated or within the throttle window.
class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  static const _throttleDuration = Duration(seconds: 30);
  DateTime? _lastRefreshedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Guard: skip if not authenticated
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    // Guard: throttle to avoid excessive refetches
    final now = DateTime.now();
    if (_lastRefreshedAt != null &&
        now.difference(_lastRefreshedAt!) < _throttleDuration) {
      return;
    }
    _lastRefreshedAt = now;

    // Invalidate all key data providers.
    // Only currently-watched providers will actually refetch.
    ref.invalidate(activeUserTasksProvider);
    ref.invalidate(activeRefereeTasksProvider);
    ref.invalidate(taskProvider);
    ref.invalidate(pointWalletProvider);
    ref.invalidate(trialPointWalletProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
