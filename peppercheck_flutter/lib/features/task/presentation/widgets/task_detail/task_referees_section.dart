import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskRefereesSection extends ConsumerStatefulWidget {
  final Task task;

  const TaskRefereesSection({super.key, required this.task});

  @override
  ConsumerState<TaskRefereesSection> createState() =>
      _TaskRefereesSectionState();
}

class _TaskRefereesSectionState extends ConsumerState<TaskRefereesSection> {
  bool _isCancelling = false;

  String? _getCurrentUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  bool _isCurrentUserMatchedReferee(RefereeRequest request) {
    final userId = _getCurrentUserId();
    if (userId == null) return false;
    return request.matchedRefereeId == userId;
  }

  Future<void> _onCancelTapped(RefereeRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.task.detail.cancelAssignment.dialogTitle),
        content: Text(t.task.detail.cancelAssignment.dialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isCancelling = true);

    try {
      await ref
          .read(matchingRepositoryProvider)
          .cancelRefereeAssignment(request.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.task.detail.cancelAssignment.success)),
      );

      ref.invalidate(taskProvider(widget.task.id));
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
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.refereeRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return BaseSection(
      title: t.task.detail.sectionRequests,
      child: Column(
        children: [
          for (int i = 0; i < widget.task.refereeRequests.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.cardGap),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.cardPaddingHorizontal,
                vertical: AppSizes.cardPaddingVertical,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
              ),
              child: Row(
                children: [
                  if (widget.task.refereeRequests[i].referee?.avatarUrl != null)
                    CircleAvatar(
                      radius: AppSizes.taskCardIconSize / 2,
                      backgroundImage: NetworkImage(
                        widget.task.refereeRequests[i].referee!.avatarUrl!,
                      ),
                      backgroundColor: Colors.transparent,
                    )
                  else
                    const Icon(
                      Icons.person,
                      color: AppColors.textSecondary,
                      size: AppSizes.taskCardIconSize,
                    ),
                  const SizedBox(width: AppSizes.cardIconGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.refereeRequests[i].matchingStrategy,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${t.task.detail.labelStatus}: ${widget.task.refereeRequests[i].status}',
                          style:
                              const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (widget.task.refereeRequests[i].status == 'accepted' &&
                      _isCurrentUserMatchedReferee(
                        widget.task.refereeRequests[i],
                      ))
                    _CancelButton(
                      isLoading: _isCancelling,
                      onPressed: _isCancelling
                          ? null
                          : () => _onCancelTapped(
                                widget.task.refereeRequests[i],
                              ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _CancelButton({required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final bool active = onPressed != null && !isLoading;

    final contentColor = active
        ? AppColors.textError
        : AppColors.textPrimary.withValues(alpha: 0.4);
    final borderColor = active
        ? AppColors.textError.withValues(alpha: 0.5)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    return OutlinedButton(
      onPressed: active ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: contentColor,
        side: BorderSide(color: borderColor, width: 1),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
      ),
      child: isLoading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(contentColor),
              ),
            )
          : Text(
              t.task.detail.cancelAssignment.button,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: contentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}
