import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_dialog.dart';
import 'package:peppercheck_flutter/common_widgets/destructive_action_button.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';
import 'package:peppercheck_flutter/features/home/ui/home_view_model.dart';
import 'package:peppercheck_flutter/features/matching/application/matching_config_provider.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/ui/task_role_provider.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

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

  /// The caller's own referee request, or null when the viewer is the tasker
  /// or a stranger. Watched from build, read from callbacks.
  RefereeRequest? _watchMyRequest() =>
      ref.watch(taskRoleProvider(widget.task.id)).value?.myRequest;

  RefereeRequest? _readMyRequest() =>
      ref.read(taskRoleProvider(widget.task.id)).value?.myRequest;

  // Judgement states from which the referee's involvement cannot be undone:
  // approved is awaiting tasker confirmation, the timeouts and confirmed are
  // terminal. (rejected stays withdrawable since the tasker may resubmit
  // evidence and the referee would re-review.)
  static const _terminalJudgementStatuses = {
    'approved',
    'review_timeout',
    'evidence_timeout',
    'confirmed',
  };

  /// The server owns the cutoff and enforces it; this only decides whether
  /// offering the button would be a dead end. Until the config loads the
  /// button stays hidden rather than promising an action the server may reject.
  bool _canWithdraw(RefereeRequest myRequest, int? cancelDeadlineHours) {
    if (myRequest.status != 'accepted') return false;
    if (cancelDeadlineHours == null) return false;

    final judgementStatus = myRequest.judgement?.status;
    if (judgementStatus != null &&
        _terminalJudgementStatuses.contains(judgementStatus)) {
      return false;
    }

    if (widget.task.dueDate == null) return true;
    final due = DateTime.parse(widget.task.dueDate!);
    final cutoff = DateTime.now().add(Duration(hours: cancelDeadlineHours));
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
            child: Text(t.task.detail.cancelAssignment.dialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    // Captured before the pop below, which takes this widget's context with it.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final myRequest = _readMyRequest();
      if (myRequest == null) return;
      await ref.read(matchingRepositoryProvider).cancelAssignment(myRequest.id);
      if (!mounted) return;

      ref.invalidate(activeUserTasksProvider);
      ref.invalidate(activeRefereeTasksProvider);

      // Withdrawing ends this referee's access to the task, so re-reading the
      // detail would 404. Leave the screen instead of refetching it.
      context.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(t.task.detail.cancelAssignment.success)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t.task.detail.cancelAssignment.error(
              // Prefer the API envelope's message over the exception's own
              // toString, which would leak the request id into the snackbar.
              message: e is ApiException ? e.message : e.toString(),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRequest = _watchMyRequest();
    final cancelDeadlineHours = ref
        .watch(matchingConfigProvider)
        .value
        ?.cancelDeadlineHours;
    if (myRequest == null || !_canWithdraw(myRequest, cancelDeadlineHours)) {
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
