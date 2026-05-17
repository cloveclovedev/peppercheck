import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/config/app_environment.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class EnvironmentBanner extends ConsumerWidget {
  final Widget child;

  const EnvironmentBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(appEnvironmentProvider);
    switch (env) {
      case AppEnvironment.production:
        return child;
      case AppEnvironment.staging:
        return Banner(
          message: 'STAGING',
          location: BannerLocation.topEnd,
          color: AppColors.accentYellowLight,
          child: child,
        );
      case AppEnvironment.debug:
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          color: AppColors.accentGreenLight,
          child: child,
        );
    }
  }
}
