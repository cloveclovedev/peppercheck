import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueDateFormatted = task.dueDate != null
        ? DateFormat('M/d H:mm').format(DateTime.parse(task.dueDate!).toLocal())
        : '';

    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final statuses = task.getDetailedStatuses(currentUserId);

    return Material(
      color: AppColors.backgroundWhite,
      borderRadius: BorderRadius.circular(AppSizes.baseCardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            onTap ?? () => context.push('/task_detail/${task.id}', extra: task),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.baseCardPaddingHorizontal,
            vertical: AppSizes.baseCardPaddingVertical,
          ),
          child: Row(
            children: [
              _buildLeading(currentUserId),
              const SizedBox(width: AppSizes.baseCardIconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.taskCardTitleInfoGap),
                    Text(
                      dueDateFormatted,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.taskCardStatusGap),
              _buildStatusLabels(context, statuses),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(String currentUserId) {
    final isOwnTask = task.taskerId == currentUserId;

    if (isOwnTask) {
      final matchedReferees = task.refereeRequests
          .where((r) => r.referee != null)
          .map((r) => r.referee!)
          .take(2)
          .toList();
      if (matchedReferees.isEmpty) return const _AvatarPlaceholder();
      return _RefereeAvatarStack(referees: matchedReferees);
    }

    final taskerAvatarUrl = task.tasker?.avatarUrl;
    if (taskerAvatarUrl == null) return const _AvatarPlaceholder();
    return CircleAvatar(
      radius: AppSizes.avatarSizeMedium / 2,
      backgroundImage: NetworkImage(taskerAvatarUrl),
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildStatusLabels(BuildContext context, List<String> statuses) {
    if (statuses.length == 1) {
      final style = _getStatusStyle(statuses[0]);
      return Text(
        style.text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: style.color,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < statuses.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacingTiny,
              ),
              child: Text(
                '|',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          () {
            final style = _getStatusStyle(statuses[i]);
            return Text(
              style.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: style.color,
                fontWeight: FontWeight.bold,
              ),
            );
          }(),
        ],
      ],
    );
  }

  ({String text, Color color}) _getStatusStyle(String statusKey) {
    switch (statusKey) {
      case 'draft':
        return (text: t.task.status.draft, color: AppColors.textMuted);
      case 'matching':
        return (text: t.task.status.matching, color: AppColors.accentYellow);
      case 'matching_complete':
        return (
          text: t.task.status.matchingComplete,
          color: AppColors.accentGreenLight,
        );
      case 'matching_failed':
        return (text: t.task.status.matchingFailed, color: AppColors.accentRed);
      case 'awaiting_evidence':
        return (
          text: t.task.status.awaitingEvidence,
          color: AppColors.accentYellow,
        );
      case 'evidence_timeout':
        return (
          text: t.task.status.evidenceTimeout,
          color: AppColors.textSecondary,
        );
      case 'in_review':
        return (text: t.task.status.inReview, color: AppColors.accentBlueLight);
      case 'approved':
        return (
          text: t.task.status.approved,
          color: AppColors.accentGreenLight,
        );
      case 'rejected':
        return (text: t.task.status.rejected, color: AppColors.accentBlue);
      case 'review_timeout':
        return (
          text: t.task.status.reviewTimeout,
          color: AppColors.textSecondary,
        );
      case 'payment_processing':
        return (
          text: t.task.status.paymentProcessing,
          color: AppColors.accentYellow,
        );
      case 'closed':
        return (text: t.task.status.closed, color: AppColors.accentGreen);
      default:
        return (text: statusKey, color: AppColors.textPrimary);
    }
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.person,
      color: AppColors.textSecondary,
      size: AppSizes.avatarSizeMedium,
    );
  }
}

class _RefereeAvatarStack extends StatelessWidget {
  final List<Profile> referees;

  const _RefereeAvatarStack({required this.referees});

  @override
  Widget build(BuildContext context) {
    if (referees.length == 1) {
      return _RefereeAvatarBubble(profile: referees.first);
    }

    const offset = AppSizes.avatarSizeMedium * 0.6;
    const bubbleSize =
        AppSizes.avatarSizeMedium + 2 * AppSizes.avatarStackRingWidth;
    final width = bubbleSize + (referees.length - 1) * offset;

    return SizedBox(
      width: width,
      height: bubbleSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < referees.length; i++)
            Positioned(
              left: i * offset,
              child: _RefereeAvatarBubble(profile: referees[i], showRing: true),
            ),
        ],
      ),
    );
  }
}

class _RefereeAvatarBubble extends StatelessWidget {
  final Profile profile;
  final bool showRing;

  const _RefereeAvatarBubble({required this.profile, this.showRing = false});

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();
    if (!showRing) return avatar;

    const total = AppSizes.avatarSizeMedium + 2 * AppSizes.avatarStackRingWidth;
    return Container(
      width: total,
      height: total,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundWhite,
      ),
      child: avatar,
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = profile.avatarUrl;
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: AppSizes.avatarSizeMedium / 2,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.transparent,
      );
    }
    return const Icon(
      Icons.person,
      color: AppColors.textSecondary,
      size: AppSizes.avatarSizeMedium,
    );
  }
}
