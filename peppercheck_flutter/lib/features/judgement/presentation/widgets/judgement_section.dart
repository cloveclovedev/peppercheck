import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/common_widgets/base_text_field.dart';
import 'package:peppercheck_flutter/common_widgets/primary_action_button.dart';
import 'package:peppercheck_flutter/features/judgement/domain/judgement.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/judgement/presentation/controllers/judgement_controller.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JudgementSection extends ConsumerStatefulWidget {
  final Task task;

  const JudgementSection({super.key, required this.task});

  @override
  ConsumerState<JudgementSection> createState() => _JudgementSectionState();
}

class _JudgementSectionState extends ConsumerState<JudgementSection> {
  final _commentController = TextEditingController();
  final _confirmCommentController = TextEditingController();
  late final ConfettiController _confettiLeftController;
  late final ConfettiController _confettiRightController;
  bool? _selectedIsPositive;

  @override
  void initState() {
    super.initState();
    _confettiLeftController =
        ConfettiController(duration: const Duration(seconds: 1));
    _confettiRightController =
        ConfettiController(duration: const Duration(seconds: 1));
    _commentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confettiLeftController.dispose();
    _confettiRightController.dispose();
    _commentController.dispose();
    _confirmCommentController.dispose();
    super.dispose();
  }

  RefereeRequest? _getCurrentUserRequest() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    for (final req in widget.task.refereeRequests) {
      if (req.matchedRefereeId == userId) return req;
    }
    return null;
  }

  bool _isCurrentUserTasker() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return userId != null && widget.task.taskerId == userId;
  }

  void _submit(String status) {
    final judgement = _getCurrentUserRequest()?.judgement;
    if (judgement == null) return;

    ref
        .read(judgementControllerProvider.notifier)
        .submit(
          taskId: widget.task.id,
          judgementId: judgement.id,
          status: status,
          comment: _commentController.text,
          onSuccess: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t.task.judgement.success)));
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final completedRequests = widget.task.refereeRequests
        .where((req) =>
            req.judgement != null &&
            (req.judgement!.status == 'approved' ||
                req.judgement!.status == 'rejected' ||
                req.judgement!.status == 'review_timeout'))
        .toList();

    final currentRequest = _getCurrentUserRequest();
    final showForm = currentRequest?.judgement != null &&
        currentRequest!.judgement!.status == 'in_review';

    if (completedRequests.isEmpty && !showForm) {
      return const SizedBox.shrink();
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Column(
          children: [
            if (completedRequests.isNotEmpty)
              _buildResultView(completedRequests),
            if (showForm) _buildFormView(),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: ConfettiWidget(
            confettiController: _confettiLeftController,
            blastDirection: -pi / 3,
            emissionFrequency: 0.03,
            numberOfParticles: 12,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              AppColors.accentYellowLight,
              AppColors.accentGreenLight,
              AppColors.backgroundDark,
              AppColors.accentYellow,
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: ConfettiWidget(
            confettiController: _confettiRightController,
            blastDirection: -2 * pi / 3,
            emissionFrequency: 0.03,
            numberOfParticles: 12,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              AppColors.accentYellowLight,
              AppColors.accentGreenLight,
              AppColors.backgroundDark,
              AppColors.accentYellow,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(List<RefereeRequest> completedRequests) {
    return BaseSection(
      title: t.task.judgement.title,
      child: Column(
        children: [
          for (int i = 0; i < completedRequests.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.cardGap),
            if (completedRequests[i].judgement!.status == 'review_timeout')
              _buildReviewTimeoutCard(completedRequests[i])
            else
              _buildResultCard(completedRequests[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewTimeoutCard(RefereeRequest request) {
    final judgement = request.judgement!;
    final state = ref.watch(judgementControllerProvider);
    final isLoading = state.isLoading;
    final isTasker = _isCurrentUserTasker();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.cardPaddingHorizontal,
        vertical: AppSizes.cardPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.textError, size: 20),
              const SizedBox(width: AppSizes.spacingTiny),
              Expanded(
                child: Text(
                  t.task.judgement.reviewTimeout.description,
                  style: TextStyle(color: AppColors.textError),
                ),
              ),
            ],
          ),
          if (isTasker && !judgement.isConfirmed) ...[
            const SizedBox(height: AppSizes.spacingSmall),
            if (state.hasError) ...[
              Text(
                state.error.toString(),
                style: TextStyle(color: AppColors.textError),
              ),
              const SizedBox(height: AppSizes.spacingSmall),
            ],
            PrimaryActionButton(
              text: t.task.judgement.reviewTimeout.confirm,
              icon: Icons.check,
              onPressed:
                  isLoading ? null : () => _confirmReviewTimeout(judgement),
              isLoading: isLoading,
            ),
          ] else if (isTasker && judgement.isConfirmed) ...[
            const SizedBox(height: AppSizes.spacingSmall),
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.accentGreen, size: 16),
                const SizedBox(width: AppSizes.spacingTiny),
                Text(
                  t.task.judgement.reviewTimeout.confirmed,
                  style: TextStyle(color: AppColors.accentGreen),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(RefereeRequest request) {
    final judgement = request.judgement!;
    final isApproved = judgement.status == 'approved';

    final String statusText;
    final Color statusColor;

    if (isApproved) {
      statusText = t.task.judgement.approved;
      statusColor = AppColors.accentGreen;
    } else {
      statusText = t.task.judgement.rejected;
      statusColor = AppColors.textError;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.cardPaddingHorizontal,
        vertical: AppSizes.cardPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (request.referee?.avatarUrl != null)
                CircleAvatar(
                  radius: AppSizes.taskCardIconSize / 2,
                  backgroundImage: NetworkImage(
                    request.referee!.avatarUrl!,
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
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    if (judgement.comment != null)
                      Text(
                        judgement.comment!,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              if (judgement.isConfirmed && _isCurrentUserTasker())
                Padding(
                  padding: const EdgeInsets.only(left: AppSizes.spacingSmall),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.accentGreen,
                    size: AppSizes.taskCardIconSize,
                  ),
                ),
            ],
          ),
          if (_isCurrentUserTasker() && !judgement.isConfirmed)
            _buildConfirmArea(judgement),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    final state = ref.watch(judgementControllerProvider);
    final isLoading = state.isLoading;

    return BaseSection(
      title: t.task.judgement.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextField(
            value: _commentController.text,
            onValueChange: (_) {},
            label: t.task.judgement.comment,
            maxLines: 5,
            minLines: 1,
            controller: _commentController,
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          if (state.hasError) ...[
            Text(
              state.error.toString(),
              style: TextStyle(color: AppColors.textError),
            ),
            const SizedBox(height: AppSizes.spacingSmall),
          ],
          Row(
            children: [
              Expanded(
                child: PrimaryActionButton(
                  text: t.task.judgement.approve,
                  icon: Icons.check,
                  onPressed:
                      _commentController.text.trim().isNotEmpty && !isLoading
                          ? () => _submit('approved')
                          : null,
                  isLoading: isLoading,
                ),
              ),
              const SizedBox(width: AppSizes.spacingSmall),
              Expanded(
                child: _RejectButton(
                  text: t.task.judgement.reject,
                  onPressed:
                      _commentController.text.trim().isNotEmpty && !isLoading
                          ? () => _submit('rejected')
                          : null,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submitConfirm(Judgement judgement) {
    if (_selectedIsPositive == null) return;

    ref
        .read(judgementControllerProvider.notifier)
        .confirmJudgement(
          taskId: widget.task.id,
          judgementId: judgement.id,
          isPositive: _selectedIsPositive!,
          comment: _confirmCommentController.text.trim().isEmpty
              ? null
              : _confirmCommentController.text.trim(),
          onSuccess: () {
            if (judgement.status == 'approved') {
              _confettiLeftController.play();
              _confettiRightController.play();
            }
            setState(() {
              _selectedIsPositive = null;
              _confirmCommentController.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.task.judgement.confirm.success)),
            );
          },
        );
  }

  void _confirmReviewTimeout(Judgement judgement) {
    ref
        .read(judgementControllerProvider.notifier)
        .confirmReviewTimeout(
          taskId: widget.task.id,
          judgementId: judgement.id,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.task.judgement.reviewTimeout.success)),
            );
          },
        );
  }

  Widget _buildConfirmArea(Judgement judgement) {
    final state = ref.watch(judgementControllerProvider);
    final isLoading = state.isLoading;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacingTiny),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSizes.spacingTiny),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.task.judgement.confirm.question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacingSmall),
              _RatingIconButton(
                icon: Icons.thumb_up_outlined,
                selectedIcon: Icons.thumb_up,
                isSelected: _selectedIsPositive == true,
                color: AppColors.accentGreen,
                onTap: isLoading
                    ? null
                    : () => setState(() => _selectedIsPositive = true),
              ),
              const SizedBox(width: AppSizes.spacingSmall),
              _RatingIconButton(
                icon: Icons.thumb_down_outlined,
                selectedIcon: Icons.thumb_down,
                isSelected: _selectedIsPositive == false,
                color: AppColors.textError,
                onTap: isLoading
                    ? null
                    : () => setState(() => _selectedIsPositive = false),
              ),
            ],
          ),
          BaseTextField(
            value: _confirmCommentController.text,
            onValueChange: (_) {},
            label: t.task.judgement.confirm.comment,
            maxLines: 3,
            minLines: 1,
            controller: _confirmCommentController,
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          if (state.hasError) ...[
            Text(
              state.error.toString(),
              style: TextStyle(color: AppColors.textError),
            ),
            const SizedBox(height: AppSizes.spacingSmall),
          ],
          PrimaryActionButton(
            text: t.task.judgement.confirm.submit,
            icon: Icons.check,
            onPressed: _selectedIsPositive != null && !isLoading
                ? () => _submitConfirm(judgement)
                : null,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

/// Reject button styled with error/destructive colors
class _RejectButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _RejectButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = onPressed != null && !isLoading;

    final containerColor = active
        ? AppColors.textError.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.05);
    final contentColor = active
        ? AppColors.textError
        : AppColors.textPrimary.withValues(alpha: 0.4);
    final borderColor = active
        ? AppColors.textError.withValues(alpha: 0.5)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: active ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: containerColor,
          foregroundColor: contentColor,
          side: BorderSide(color: borderColor, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(contentColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 16, color: contentColor),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RatingIconButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  const _RatingIconButton({
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected
        ? color
        : AppColors.textPrimary.withValues(alpha: 0.4);

    return IconButton(
      onPressed: onTap,
      icon: Icon(
        isSelected ? selectedIcon : icon,
        color: fgColor,
        size: AppSizes.taskCardIconSize,
      ),
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? color.withValues(alpha: 0.1)
            : Colors.transparent,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
      ),
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(AppSizes.spacingTiny),
    );
  }
}
