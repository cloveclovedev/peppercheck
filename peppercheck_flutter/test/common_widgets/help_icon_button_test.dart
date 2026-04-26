import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/common_widgets/help_icon_button.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

void main() {
  testWidgets('HelpIconButton opens dialog with provided title and body', (
    tester,
  ) async {
    LocaleSettings.useDeviceLocale();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HelpIconButton(
              title: 'My help title',
              body: 'Detailed explanation of the concept.',
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.text('My help title'), findsNothing);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.text('My help title'), findsOneWidget);
    expect(find.text('Detailed explanation of the concept.'), findsOneWidget);
  });

  testWidgets('HelpIconButton does not exceed icon size in its visual bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HelpIconButton(title: 't', body: 'b'),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(HelpIconButton));
    // Icon is 16px + small padding (~spacingMicro on each side ≈ 4px total).
    // Sanity bound: should never approach IconButton's 48x48 default.
    expect(size.height, lessThan(28));
    expect(size.width, lessThan(28));
  });
}
