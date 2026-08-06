import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/matching/application/matching_config_provider.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/matching_config.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/judgement/domain/judgement.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_viewer_role.dart';
import 'package:peppercheck_flutter/features/task/ui/task_role_provider.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/withdraw_matching_button.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

import 'withdraw_button_test.mocks.dart';

const _config = MatchingConfig(
  openDeadlineHours: 24,
  cancelDeadlineHours: 12,
  rematchCutoffHours: 14,
  maxRefereesPerTask: 2,
  matchingPointCost: 1,
);

RefereeRequest _request({String status = 'accepted', Judgement? judgement}) =>
    RefereeRequest(
      id: 'r1',
      taskId: 't1',
      status: status,
      matchedRefereeId: 'u_me',
      createdAt: '2026-07-25T00:00:00Z',
      judgement: judgement,
    );

Task _task({required Duration untilDue}) => Task(
  id: 't1',
  taskerId: 'u_owner',
  title: 'Run 5km',
  status: 'open',
  dueDate: DateTime.now().add(untilDue).toIso8601String(),
  createdAt: '2026-07-25T00:00:00Z',
  refereeRequests: [_request()],
);

@GenerateNiceMocks([MockSpec<MatchingRepository>()])
void main() {
  setUpAll(() => LocaleSettings.useDeviceLocale());

  late MockMatchingRepository repository;

  setUp(() => repository = MockMatchingRepository());

  Future<void> pump(
    WidgetTester tester, {
    required Task task,
    required RefereeRequest? myRequest,
    MatchingConfig? config = _config,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchingRepositoryProvider.overrideWithValue(repository),
          taskRoleProvider('t1').overrideWith(
            (ref) async =>
                TaskViewerRole(isTasker: false, myRequest: myRequest),
          ),
          matchingConfigProvider.overrideWith((ref) async {
            if (config == null) {
              // Never resolves: the config is still loading.
              return Completer<MatchingConfig>().future;
            }
            return config;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: WithdrawMatchingButton(task: task)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  final button = find.text(t.task.detail.cancelAssignment.button);

  testWidgets('shows before the cancel cutoff', (tester) async {
    await pump(
      tester,
      task: _task(untilDue: const Duration(days: 2)),
      myRequest: _request(),
    );

    expect(button, findsOneWidget);
  });

  testWidgets('hides inside the cancel cutoff', (tester) async {
    await pump(
      tester,
      task: _task(untilDue: const Duration(hours: 6)),
      myRequest: _request(),
    );

    expect(button, findsNothing);
  });

  testWidgets('hides while the config is still loading', (tester) async {
    await pump(
      tester,
      task: _task(untilDue: const Duration(days: 2)),
      myRequest: _request(),
      config: null,
    );

    expect(button, findsNothing);
  });

  testWidgets('hides for a viewer with no request of their own', (
    tester,
  ) async {
    await pump(
      tester,
      task: _task(untilDue: const Duration(days: 2)),
      myRequest: null,
    );

    expect(button, findsNothing);
  });

  testWidgets('hides once the judgement is terminal', (tester) async {
    await pump(
      tester,
      task: _task(untilDue: const Duration(days: 2)),
      myRequest: _request(
        judgement: const Judgement(
          id: 'r1',
          status: 'approved',
          createdAt: '2026-07-25T00:00:00Z',
          updatedAt: '2026-07-25T00:00:00Z',
        ),
      ),
    );

    expect(button, findsNothing);
  });

  testWidgets('cancels the caller own request on confirm', (tester) async {
    when(
      repository.cancelAssignment('r1'),
    ).thenAnswer((_) async => _task(untilDue: const Duration(days: 2)));

    await pump(
      tester,
      task: _task(untilDue: const Duration(days: 2)),
      myRequest: _request(),
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.task.detail.cancelAssignment.dialogConfirm));
    await tester.pumpAndSettle();

    verify(repository.cancelAssignment('r1')).called(1);
  });
}
