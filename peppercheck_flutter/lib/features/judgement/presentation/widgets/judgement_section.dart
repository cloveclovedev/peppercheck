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
  bool? _selectedIsPositive;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(() => setState(() {}));
    _confirmCommentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
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
                req.judgement!.status == 'rejected'))
        .toList();

    final currentRequest = _getCurrentUserRequest();
    final showForm = currentRequest?.judgement != null &&
        currentRequest!.judgement!.status == 'in_review';

    if (completedRequests.isEmpty && !showForm) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (completedRequests.isNotEmpty) _buildResultView(completedRequests),
        if (showForm) _buildFormView(),
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
            _buildResultCard(completedRequests[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(RefereeRequest request) {
    final judgement = request.judgement!;
    final isApproved = judgement.status == 'approved';
    final statusText =
        isApproved ? t.task.judgement.approved : t.task.judgement.rejected;
    final statusColor =
        isApproved ? AppColors.accentGreen : AppColors.textError;

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
          if (_isCurrentUserTasker() &&
              !judgement.isConfirmed &&
              (judgement.status == 'approved' || judgement.status == 'rejected'))
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

  Widget _buildConfirmArea(Judgement judgement) {
    final state = ref.watch(judgementControllerProvider);
    final isLoading = state.isLoading;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.border),
          const SizedBox(height: AppSizes.spacingSmall),
          Text(
            t.task.judgement.confirm.question,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          Row(
            children: [
              Expanded(
                child: _RatingButton(
                  icon: Icons.thumb_up,
                  selectedIcon: Icons.thumb_up,
                  label: t.task.judgement.confirm.fair,
                  isSelected: _selectedIsPositive == true,
                  color: AppColors.accentGreen,
                  onTap: isLoading
                      ? null
                      : () => setState(() => _selectedIsPositive = true),
                ),
              ),
              const SizedBox(width: AppSizes.spacingSmall),
              Expanded(
                child: _RatingButton(
                  icon: Icons.thumb_down,
                  selectedIcon: Icons.thumb_down,
                  label: t.task.judgement.confirm.unfair,
                  isSelected: _selectedIsPositive == false,
                  color: AppColors.textError,
                  onTap: isLoading
                      ? null
                      : () => setState(() => _selectedIsPositive = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingSmall),
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

class _RatingButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  const _RatingButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? color.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.05);
    final fgColor = isSelected
        ? color
        : AppColors.textPrimary.withValues(alpha: 0.4);
    final borderColor = isSelected
        ? color.withValues(alpha: 0.5)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacingStandard,
          vertical: AppSizes.spacingSmall,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 20,
              color: fgColor,
            ),
            const SizedBox(width: AppSizes.spacingSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
