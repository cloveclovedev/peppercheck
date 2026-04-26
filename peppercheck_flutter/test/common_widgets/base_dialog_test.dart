import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/common_widgets/base_dialog.dart';

void main() {
  testWidgets('BaseDialog renders title, content, and actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BaseDialog(
                  title: 'Help title',
                  content: const Text('Help body content'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Help title'), findsOneWidget);
    expect(find.text('Help body content'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
