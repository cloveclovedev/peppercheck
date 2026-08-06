import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/common_widgets/destructive_action_button.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/ui/task_deletion_view_model.dart';
import 'package:peppercheck_flutter/features/task/ui/widgets/task_detail/delete_task_confirmation_dialog.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class DeleteTaskButton extends ConsumerWidget {
  final Task task;

  const DeleteTaskButton({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskDeletionViewModelProvider);
    final isLoading = state.isLoading;

    return DestructiveActionButton(
      text: t.task.deletion.button,
      icon: Icons.delete_outline,
      isLoading: isLoading,
      onPressed: isLoading ? null : () => _showConfirmation(context, ref),
    );
  }

  void _showConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => DeleteTaskConfirmationDialog(
        onConfirm: () => _executeDelete(context, ref),
      ),
    );
  }

  Future<void> _executeDelete(BuildContext context, WidgetRef ref) async {
    await ref
        .read(taskDeletionViewModelProvider.notifier)
        .deleteTask(
          task.id,
          onSuccess: () {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.task.deletion.deletedSnackbar)),
            );
            context.go('/');
          },
        );

    final newState = ref.read(taskDeletionViewModelProvider);
    if (newState.hasError && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.task.deletion.failedSnackbar)));
    }
  }
}
