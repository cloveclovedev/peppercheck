import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_dialog.dart';
import 'package:peppercheck_flutter/common_widgets/destructive_action_button.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/matching/matching_constants.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WithdrawMatchingButton extends ConsumerStatefulWidget {
  final Task task;

  const WithdrawMatchingButton({super.key, required this.task});

  @override
  ConsumerState<WithdrawMatchingButton> createState() =>
      _WithdrawMatchingButtonState();
}

class _WithdrawMatchingButtonState
    extends ConsumerState<WithdrawMatchingButton> {
  bool _isLoading = false;

  RefereeRequest? _myRequest() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    for (final r in widget.task.refereeRequests) {
      if (r.matchedRefereeId == userId) return r;
    }
    return null;
  }

  bool _canWithdraw(RefereeRequest myRequest) {
    if (myRequest.status != 'accepted') return false;
    if (widget.task.dueDate == null) return true;
    final due = DateTime.parse(widget.task.dueDate!);
    final cutoff = DateTime.now().add(
      const Duration(hours: kRefereeCancelDeadlineHours),
    );
    return due.isAfter(cutoff);
  }

  Future<void> _onPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BaseDialog(
        title: t.task.detail.cancelAssignment.dialogTitle,
        content: Text(t.task.detail.cancelAssignment.dialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.textError),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final myRequest = _myRequest();
      if (myRequest == null) return;
      await ref
          .read(matchingRepositoryProvider)
          .cancelRefereeAssignment(myRequest.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.task.detail.cancelAssignment.success)),
      );

      ref.invalidate(taskProvider(widget.task.id));
      ref.invalidate(activeUserTasksProvider);
      ref.invalidate(activeRefereeTasksProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.task.detail.cancelAssignment.error(message: e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRequest = _myRequest();
    if (myRequest == null || !_canWithdraw(myRequest)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingLarge),
      child: Align(
        alignment: Alignment.centerRight,
        child: DestructiveActionButton(
          text: t.task.detail.cancelAssignment.button,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _onPressed,
          fullWidth: false,
        ),
      ),
    );
  }
}
