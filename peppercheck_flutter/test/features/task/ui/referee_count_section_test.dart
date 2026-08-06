import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_creation/referee_count_section.dart';

Widget _host({
  required int selected,
  required int maxCount,
  required bool loading,
  required ValueChanged<int> onChanged,
}) => MaterialApp(
  home: Scaffold(
    body: RefereeCountSection(
      selected: selected,
      maxCount: maxCount,
      loading: loading,
      onChanged: onChanged,
    ),
  ),
);

void main() {
  testWidgets('renders one button per allowed count and no point cost', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(selected: 1, maxCount: 2, loading: false, onChanged: (_) {}),
    );

    expect(find.text('1人'), findsOneWidget);
    expect(find.text('2人'), findsOneWidget);
    expect(find.text('3人'), findsNothing);
    expect(find.textContaining('pt'), findsNothing);
  });

  testWidgets('reports the tapped count', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      _host(selected: 1, maxCount: 2, loading: false, onChanged: tapped.add),
    );

    await tester.tap(find.text('2人'));
    await tester.pump();

    expect(tapped, [2]);
  });

  testWidgets('is disabled while the config is loading', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      _host(selected: 1, maxCount: 1, loading: true, onChanged: tapped.add),
    );

    await tester.tap(find.text('1人'));
    await tester.pump();

    expect(tapped, isEmpty);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
  });

  testWidgets('clamps a stale selection once a smaller maximum loads', (
    tester,
  ) async {
    final clamped = <int>[];
    await tester.pumpWidget(
      _host(selected: 2, maxCount: 1, loading: false, onChanged: clamped.add),
    );
    await tester.pump();

    expect(clamped, [1]);
  });

  testWidgets('does not clamp while the config is still loading', (
    tester,
  ) async {
    final clamped = <int>[];
    await tester.pumpWidget(
      _host(selected: 2, maxCount: 1, loading: true, onChanged: clamped.add),
    );
    await tester.pump();

    expect(clamped, isEmpty);
  });
}
