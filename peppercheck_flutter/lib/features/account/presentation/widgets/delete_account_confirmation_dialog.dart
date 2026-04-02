import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class DeleteAccountConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteAccountConfirmationDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        t.account.actions.confirmTitle,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLabel(context, t.account.actions.confirmDeletedLabel),
            const SizedBox(height: AppSizes.spacingTiny),
            _buildBody(context, t.account.actions.confirmDeletedItems),
            const SizedBox(height: AppSizes.spacingMedium),
            _buildLabel(context, t.account.actions.confirmAnonymizedLabel),
            const SizedBox(height: AppSizes.spacingTiny),
            _buildBody(context, t.account.actions.confirmAnonymizedItems),
            const SizedBox(height: AppSizes.spacingMedium),
            _buildBody(context, t.account.actions.confirmRetainedNote),
            const SizedBox(height: AppSizes.spacingSmall),
            Text(
              t.account.actions.confirmIapNotice,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(t.account.actions.cancelButton),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showFinalConfirmation(context);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.textError),
          child: Text(t.account.actions.deleteButton),
        ),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBody(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
    );
  }

  void _showFinalConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          t.account.actions.confirmTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          t.account.actions.finalConfirmDescription,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textError),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: Text(t.account.actions.cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.textError),
            child: Text(t.account.actions.deleteButton),
          ),
        ],
      ),
    );
  }
}

class PayoutFailedDialog extends StatelessWidget {
  final int rewardBalance;
  final VoidCallback onForceDelete;

  const PayoutFailedDialog({
    super.key,
    required this.rewardBalance,
    required this.onForceDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        t.account.actions.payoutFailedTitle,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        t.account.actions.payoutFailedDescription(
          amount: rewardBalance.toString(),
        ),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(t.account.actions.cancelButton),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onForceDelete();
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.textError),
          child: Text(t.account.actions.deleteButton),
        ),
      ],
    );
  }
}
