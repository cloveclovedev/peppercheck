import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyRefereeRequestSection extends ConsumerStatefulWidget {
  final Task task;

  const MyRefereeRequestSection({super.key, required this.task});

  @override
  ConsumerState<MyRefereeRequestSection> createState() =>
      _MyRefereeRequestSectionState();
}

class _MyRefereeRequestSectionState
    extends ConsumerState<MyRefereeRequestSection> {
  bool _isCancelling = false;

  String? _currentUserId() => Supabase.instance.client.auth.currentUser?.id;

  RefereeRequest? _myRequest() {
    final userId = _currentUserId();
    if (userId == null) return null;
    for (final r in widget.task.refereeRequests) {
      if (r.matchedRefereeId == userId) return r;
    }
    return null;
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
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRequest = _myRequest();
    if (myRequest == null) return const SizedBox.shrink();

    final tasker = widget.task.tasker;
    final username = tasker?.username ?? '...';
    final avatarUrl = tasker?.avatarUrl;
    final strategyLabel = _strategyLabel(myRequest.matchingStrategy);
    final statusLabel = _statusLabel(myRequest.status);

    return BaseSection(
      title: t.task.detail.sectionRefereesReferee,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.baseCardPaddingHorizontal,
          vertical: AppSizes.baseCardPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(AppSizes.baseCardBorderRadius),
        ),
        child: Row(
          children: [
            if (avatarUrl != null)
              CircleAvatar(
                radius: AppSizes.baseCardIconSize / 2,
                backgroundImage: NetworkImage(avatarUrl),
                backgroundColor: Colors.transparent,
              )
            else
              const Icon(
                Icons.person,
                color: AppColors.textSecondary,
                size: AppSizes.baseCardIconSize,
              ),
            const SizedBox(width: AppSizes.baseCardIconGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$strategyLabel ($statusLabel)',
                    style: const TextStyle(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (myRequest.isObligation) ...[
                    const SizedBox(height: AppSizes.spacingTiny),
                    Text(
                      t.billing.obligationRefereeNotice,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (myRequest.status == 'accepted')
              _CancelButton(
                isLoading: _isCancelling,
                onPressed: _isCancelling
                    ? null
                    : () => _onCancelTapped(myRequest),
              ),
          ],
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

String _strategyLabel(String value) {
  switch (value) {
    case 'standard':
      return t.task.detail.matchingStrategy.standard;
    case 'premium':
      return t.task.detail.matchingStrategy.premium;
    case 'direct':
      return t.task.detail.matchingStrategy.direct;
    default:
      return value;
  }
}

String _statusLabel(String value) {
  switch (value) {
    case 'pending':
      return t.task.detail.refereeStatus.pending;
    case 'matched':
      return t.task.detail.refereeStatus.matched;
    case 'accepted':
      return t.task.detail.refereeStatus.accepted;
    case 'declined':
      return t.task.detail.refereeStatus.declined;
    case 'expired':
      return t.task.detail.refereeStatus.expired;
    case 'payment_processing':
      return t.task.detail.refereeStatus.paymentProcessing;
    case 'closed':
      return t.task.detail.refereeStatus.closed;
    case 'cancelled':
      return t.task.detail.refereeStatus.cancelled;
    default:
      return value;
  }
}
