import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/widgets/evidence_submission_section.dart';
import 'package:peppercheck_flutter/features/judgement/presentation/widgets/judgement_section.dart';
import 'package:peppercheck_flutter/features/matching/application/matching_config_provider.dart';
import 'package:peppercheck_flutter/features/matching/domain/matching_config.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/report/presentation/widgets/report_menu_button.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_viewer_role.dart';
import 'package:peppercheck_flutter/features/task/ui/task_detail_screen.dart';
import 'package:peppercheck_flutter/features/task/ui/task_detail_view_model.dart';
import 'package:peppercheck_flutter/features/task/ui/task_role_provider.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/tasker_referees_section.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/withdraw_matching_button.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

final _request = RefereeRequest(
  id: 'r1',
  taskId: 't1',
  status: 'accepted',
  matchedRefereeId: 'u_me',
  createdAt: '2026-07-25T00:00:00Z',
);

final _task = Task(
  id: 't1',
  taskerId: 'u_owner',
  title: 'Run 5km',
  status: 'open',
  // Far enough out that the withdraw cutoff cannot hide the button.
  dueDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
  createdAt: '2026-07-25T00:00:00Z',
  refereeRequests: [_request],
);

class _StubTaskDetail extends TaskDetail {
  @override
  Future<Task> build(String taskId) async => _task;
}

Future<void> _pumpDetail(WidgetTester tester, TaskViewerRole role) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskDetailProvider('t1').overrideWith(_StubTaskDetail.new),
        taskRoleProvider('t1').overrideWith((ref) async => role),
        matchingConfigProvider.overrideWith(
          (ref) async => const MatchingConfig(
            openDeadlineHours: 24,
            cancelDeadlineHours: 12,
            rematchCutoffHours: 14,
            maxRefereesPerTask: 2,
            matchingPointCost: 1,
          ),
        ),
      ],
      child: const MaterialApp(home: TaskDetailScreen(taskId: 't1')),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => LocaleSettings.useDeviceLocale());

  testWidgets('the tasker sees the referee section and no withdraw button', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      const TaskViewerRole(isTasker: true, myRequest: null),
    );

    expect(find.byType(TaskerRefereesSection), findsOneWidget);
    expect(find.byType(WithdrawMatchingButton), findsOneWidget);
    // Mounted, but it renders nothing without a request of the viewer's own.
    expect(find.text(t.task.detail.cancelAssignment.button), findsNothing);
  });

  testWidgets(
    'an assigned referee sees the withdraw button, not the referee section',
    (tester) async {
      await _pumpDetail(
        tester,
        TaskViewerRole(isTasker: false, myRequest: _request),
      );

      expect(find.byType(TaskerRefereesSection), findsNothing);
      expect(find.text(t.task.detail.cancelAssignment.button), findsOneWidget);
    },
  );

  testWidgets('Phase 4b/4c sections are not mounted', (tester) async {
    await _pumpDetail(
      tester,
      const TaskViewerRole(isTasker: true, myRequest: null),
    );

    expect(find.byType(EvidenceSubmissionSection), findsNothing);
    expect(find.byType(JudgementSection), findsNothing);
    expect(find.byType(ReportMenuButton), findsNothing);
  });
}
