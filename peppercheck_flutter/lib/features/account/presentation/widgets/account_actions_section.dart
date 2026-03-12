import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            t.account.actions.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        deletableAsync.when(
          data: (status) => _buildDeleteButton(context, ref, status.deletable, status.reasons),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _buildDeleteButton(context, ref, false, []),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    WidgetRef ref,
    bool deletable,
    List<String> reasons,
  ) {
    return Column(
      children: [
        if (!deletable && reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              t.account.actions.deleteBlocked,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        ListTile(
          title: Text(
            t.account.actions.deleteAccount,
            style: TextStyle(
              color: deletable ? Colors.red : Colors.grey,
            ),
          ),
          enabled: deletable,
          onTap: deletable
              ? () => _showConfirmation(context, ref)
              : null,
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

  Future<void> _executeDelete(BuildContext context, WidgetRef ref, {required bool force}) async {
    await ref.read(accountDeletionControllerProvider.notifier).executeDelete(
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
    if (state.hasError && state.error is PayoutFailedException && context.mounted) {
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
