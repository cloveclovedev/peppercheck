import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/common_widgets/base_bottom_sheet.dart';

void main() {
  testWidgets('showBaseBottomSheet displays title and content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBaseBottomSheet<void>(
                context: context,
                title: 'Sheet title',
                contentBuilder: (_) => const Text('Sheet body'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet title'), findsOneWidget);
    expect(find.text('Sheet body'), findsOneWidget);
  });
}
