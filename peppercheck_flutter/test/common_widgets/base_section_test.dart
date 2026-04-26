import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';

void main() {
  testWidgets('BaseSection without trailing renders title only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BaseSection(title: 'My title', child: Text('Body')),
        ),
      ),
    );

    expect(find.text('My title'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.byKey(const ValueKey('trailing-marker')), findsNothing);
  });

  testWidgets('BaseSection with trailing renders trailing adjacent to title', (
    tester,
  ) async {
    const trailingMarker = ValueKey('trailing-marker');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BaseSection(
            title: 'My title',
            trailing: SizedBox.square(key: trailingMarker, dimension: 16),
            child: Text('Body'),
          ),
        ),
      ),
    );

    expect(find.text('My title'), findsOneWidget);
    expect(find.byKey(trailingMarker), findsOneWidget);

    final titleRect = tester.getRect(find.text('My title'));
    final trailingRect = tester.getRect(find.byKey(trailingMarker));

    // Trailing sits to the right of the title with a small gap; not far-right.
    expect(trailingRect.left, greaterThan(titleRect.right));
    expect(
      trailingRect.left - titleRect.right,
      lessThan(20.0),
      reason: 'trailing should be adjacent (small gap), not at row end',
    );
  });
}
