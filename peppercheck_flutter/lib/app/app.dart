import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/routing/app_router.dart';
import 'package:peppercheck_flutter/app/theme/app_theme.dart';
import 'package:peppercheck_flutter/features/profile/presentation/timezone_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Initialize timezone controller to check/update timezone on app start/auth change
    ref.watch(timezoneControllerProvider);

    return TranslationProvider(
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'PepperCheck',
            theme: AppTheme.light,
            routerConfig: router,
            locale: TranslationProvider.of(context).flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          );
        },
      ),
    );
  }
}
