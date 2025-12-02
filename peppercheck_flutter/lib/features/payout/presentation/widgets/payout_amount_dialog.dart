import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/features/currency/domain/currency.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PayoutAmountDialog extends StatefulWidget {
  final int availableMinor;
  final Currency currency;
  final Function(int) onConfirm;

  const PayoutAmountDialog({
    super.key,
    required this.availableMinor,
    required this.currency,
    required this.onConfirm,
  });

  @override
  State<PayoutAmountDialog> createState() => _PayoutAmountDialogState();
}

class _PayoutAmountDialogState extends State<PayoutAmountDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _calculateMinorAmount(String text) {
    if (text.isEmpty) return 0;
    final value = double.tryParse(text);
    if (value == null) return 0;
    return (value * pow(10, widget.currency.exponent)).toInt();
  }

  void _validate() {
    final text = _controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = null);
      return;
    }

    final value = double.tryParse(text);
    if (value == null) {
      setState(() => _errorText = t.payout.invalidAmount);
      return;
    }

    final amountMinor = _calculateMinorAmount(text);

    if (amountMinor <= 0) {
      setState(() => _errorText = t.payout.invalidAmount);
      return;
    }

    if (amountMinor > widget.availableMinor) {
      setState(() => _errorText = t.payout.insufficientFunds);
      return;
    }

    setState(() => _errorText = null);
  }

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
        t.dashboard.requestPayout,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textBlack,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
            ],
            style: const TextStyle(color: AppColors.textBlack),
            cursorColor: AppColors.textBlack,
            decoration: InputDecoration(
              labelText: '${t.payout.amount} (${widget.currency.code})',
              labelStyle: TextStyle(
                color: AppColors.textBlack.withValues(alpha: 0.6),
              ),
              errorText: _errorText,
              filled: true,
              fillColor: AppColors.backgroundWhite,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accentBlueLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.accentBlueLight,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accentRed),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.accentRed,
                  width: 2,
                ),
              ),
            ),
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: 8),
          Text(
            t.payout.enterAmountDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textBlack.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            _validate();
            if (_errorText == null && _controller.text.isNotEmpty) {
              final amountMinor = _calculateMinorAmount(_controller.text);
              if (amountMinor > 0) {
                widget.onConfirm(amountMinor);
                Navigator.of(context).pop();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentYellow,
            foregroundColor: AppColors.textBlack,
          ),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
