import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/features/report/presentation/report_controller.dart';
import 'package:peppercheck_flutter/features/report/presentation/widgets/report_bottom_sheet.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportMenuButton extends ConsumerWidget {
  final Task task;

  const ReportMenuButton({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReportedAsync = ref.watch(hasReportedProvider(task.id));
    final alreadyReported = hasReportedAsync.asData?.value ?? false;

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'report' && !alreadyReported) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          final isTasker = task.taskerId == userId;
          final judgementId = task.refereeRequests
              .where((r) => r.judgement != null)
              .map((r) => r.judgement!.id)
              .firstOrNull;

          final reported = await showReportBottomSheet(
            context,
            taskId: task.id,
            isTasker: isTasker,
            evidenceId: task.evidence?.id,
            judgementId: judgementId,
          );

          if (reported == true) {
            ref.invalidate(hasReportedProvider(task.id));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(t.report.successMessage)));
            }
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'report',
          enabled: !alreadyReported,
          child: Text(
            alreadyReported ? t.report.menuItemReported : t.report.menuItem,
          ),
        ),
      ],
    );
  }
}
