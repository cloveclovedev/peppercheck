import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class DeleteAccountConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteAccountConfirmationDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.account.actions.confirmTitle),
      content: Text(t.account.actions.confirmDescription),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.account.actions.cancelButton),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showFinalConfirmation(context);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(t.account.actions.deleteButton),
        ),
      ],
    );
  }

  void _showFinalConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.account.actions.confirmTitle),
        content: Text(t.account.actions.finalConfirmDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.account.actions.cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      title: Text(t.account.actions.payoutFailedTitle),
      content: Text(
        t.account.actions.payoutFailedDescription(amount: rewardBalance.toString()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.account.actions.cancelButton),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onForceDelete();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(t.account.actions.deleteButton),
        ),
      ],
    );
  }
}
