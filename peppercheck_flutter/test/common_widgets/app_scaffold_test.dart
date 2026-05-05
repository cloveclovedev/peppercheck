import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

Widget _harness({required double bottomPadding, required Widget child}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: EdgeInsets.only(bottom: bottomPadding)),
          child: child,
        );
      },
    ),
  );
}

void main() {
  setUpAll(() {
    LocaleSettings.useDeviceLocale();
  });

  testWidgets(
    'AppScaffold leaves breathing room when there is no system inset',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          bottomPadding: 0,
          child: const AppScaffold.fixed(body: SizedBox.shrink()),
        ),
      );

      final scaffoldBottom = tester.getRect(find.byType(Scaffold)).bottom;
      final navBarBottom = tester.getRect(find.byType(NavigationBar)).bottom;
      final gap = scaffoldBottom - navBarBottom;

      expect(
        gap,
        AppSizes.bottomNavigationBarBreathingRoom,
        reason:
            'With padding.bottom = 0, the only contribution to the gap is '
            'the breathing room.',
      );
    },
  );

  testWidgets('AppScaffold adds breathing room on top of the system inset', (
    tester,
  ) async {
    const systemInset = 30.0;

    await tester.pumpWidget(
      _harness(
        bottomPadding: systemInset,
        child: const AppScaffold.fixed(body: SizedBox.shrink()),
      ),
    );

    final scaffoldBottom = tester.getRect(find.byType(Scaffold)).bottom;
    final navBarBottom = tester.getRect(find.byType(NavigationBar)).bottom;
    final gap = scaffoldBottom - navBarBottom;

    expect(
      gap,
      systemInset + AppSizes.bottomNavigationBarBreathingRoom,
      reason:
          'The bar should sit breathingRoom above the system inset, not '
          'flush with it.',
    );
  });
}
