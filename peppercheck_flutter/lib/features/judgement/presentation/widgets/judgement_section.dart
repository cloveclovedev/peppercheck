import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/common_widgets/base_text_field.dart';
import 'package:peppercheck_flutter/features/judgement/domain/judgement.dart';
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

  @override
  void initState() {
    super.initState();
    _commentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Judgement? _getJudgement() {
    for (final request in widget.task.refereeRequests) {
      if (request.judgement != null) {
        return request.judgement;
      }
    }
    return null;
  }

  bool _isCurrentUserReferee() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    return widget.task.refereeRequests.any(
      (req) => req.matchedRefereeId == userId,
    );
  }

  void _submit(String status) {
    final judgement = _getJudgement();
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
    final judgement = _getJudgement();
    if (judgement == null) return const SizedBox.shrink();

    final status = judgement.status;

    // Show result for approved/rejected (both tasker and referee)
    if (status == 'approved' || status == 'rejected') {
      return _buildResultView(judgement);
    }

    // Show form only for in_review + referee
    if (status == 'in_review' && _isCurrentUserReferee()) {
      return _buildFormView();
    }

    return const SizedBox.shrink();
  }

  Widget _buildResultView(Judgement judgement) {
    final isApproved = judgement.status == 'approved';
    final statusText =
        isApproved ? t.task.judgement.approved : t.task.judgement.rejected;
    final statusColor = isApproved ? AppColors.accentGreen : AppColors.textError;

    return BaseSection(
      title: t.task.judgement.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacingSmall,
              vertical: AppSizes.spacingTiny,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (judgement.comment != null) ...[
            const SizedBox(height: AppSizes.spacingSmall),
            Text(
              judgement.comment!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
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
            minLines: 3,
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
                child: ActionButton(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
