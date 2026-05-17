import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/app/config/app_environment.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/common_widgets/environment_banner.dart';

Widget _harness({required AppEnvironment env, required Widget child}) {
  return ProviderScope(
    overrides: [appEnvironmentProvider.overrideWithValue(env)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EnvironmentBanner(child: child),
    ),
  );
}

void main() {
  testWidgets('production: no Banner is rendered, child passes through', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(env: AppEnvironment.production, child: const Text('child')),
    );

    expect(find.byType(Banner), findsNothing);
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('staging: yellow STAGING Banner at topEnd', (tester) async {
    await tester.pumpWidget(
      _harness(env: AppEnvironment.staging, child: const Text('child')),
    );

    final banner = tester.widget<Banner>(find.byType(Banner));
    expect(banner.message, 'STAGING');
    expect(banner.color, AppColors.accentYellowLight);
    expect(banner.location, BannerLocation.topEnd);
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('debug: green DEBUG Banner at topEnd', (tester) async {
    await tester.pumpWidget(
      _harness(env: AppEnvironment.debug, child: const Text('child')),
    );

    final banner = tester.widget<Banner>(find.byType(Banner));
    expect(banner.message, 'DEBUG');
    expect(banner.color, AppColors.accentGreenLight);
    expect(banner.location, BannerLocation.topEnd);
    expect(find.text('child'), findsOneWidget);
  });
}
