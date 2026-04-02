import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/account/data/account_repository.dart';
import 'package:peppercheck_flutter/features/account/presentation/account_deletion_controller.dart';
import 'package:peppercheck_flutter/features/account/presentation/widgets/delete_account_confirmation_dialog.dart';
import 'package:peppercheck_flutter/features/authentication/data/authentication_repository.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class AccountActionsSection extends ConsumerWidget {
  const AccountActionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletableAsync = ref.watch(accountDeletionControllerProvider);

    return BaseSection(
      title: t.account.actions.title,
      child: deletableAsync.when(
        data: (status) =>
            _buildDeleteButton(context, ref, status.deletable, status.reasons),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildDeleteButton(context, ref, false, []),
      ),
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    WidgetRef ref,
    bool deletable,
    List<String> reasons,
  ) {
    final bool active = deletable;

    final containerColor = active
        ? AppColors.textError.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.05);
    final contentColor = active
        ? AppColors.textError
        : AppColors.textPrimary.withValues(alpha: 0.4);
    final borderColor = active
        ? AppColors.textError.withValues(alpha: 0.5)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!deletable && reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacingSmall),
            child: Text(
              t.account.actions.deleteBlocked,
              style: TextStyle(color: AppColors.textError),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: active ? () => _showConfirmation(context, ref) : null,
            style: OutlinedButton.styleFrom(
              backgroundColor: containerColor,
              foregroundColor: contentColor,
              side: BorderSide(color: borderColor, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 16, color: contentColor),
                const SizedBox(width: 6),
                Text(
                  t.account.actions.deleteAccount,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => DeleteAccountConfirmationDialog(
        onConfirm: () => _executeDelete(context, ref, force: false),
      ),
    );
  }

  Future<void> _executeDelete(
    BuildContext context,
    WidgetRef ref, {
    required bool force,
  }) async {
    await ref
        .read(accountDeletionControllerProvider.notifier)
        .executeDelete(
          force: force,
          onSuccess: () async {
            await ref.read(authenticationRepositoryProvider).signOut();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.account.actions.deletedSnackbar)),
              );
              context.go('/');
            }
          },
        );

    // Check for payout failure after execution
    final state = ref.read(accountDeletionControllerProvider);
    if (state.hasError &&
        state.error is PayoutFailedException &&
        context.mounted) {
      final error = state.error as PayoutFailedException;
      showDialog(
        context: context,
        builder: (_) => PayoutFailedDialog(
          rewardBalance: error.rewardBalance,
          onForceDelete: () => _executeDelete(context, ref, force: true),
        ),
      );
    }
  }
}
