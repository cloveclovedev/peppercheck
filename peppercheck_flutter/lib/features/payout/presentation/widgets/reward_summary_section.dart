import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class RewardSummarySection extends StatelessWidget {
  const RewardSummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch actual reward data
    final int totalEarnings = 12500;
    final int pendingAmount = 2500;
    final int availableAmount = 10000;
    final bool isPayoutSetupComplete = true; // Assume setup is done for demo
    // Use dynamic condition to avoid dead code warning
    final bool isPayoutRequested = DateTime.now().year < 2000;

    final bool canRequest =
        availableAmount > 0 && isPayoutSetupComplete && !isPayoutRequested;

    final currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

    return BaseSection(
      title: t.dashboard.totalEarnings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currencyFormat.format(totalEarnings),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: t.dashboard.pending,
                  amount: currencyFormat.format(pendingAmount),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: AppSizes.spacingMedium),
              Expanded(
                child: _SummaryItem(
                  label: t.dashboard.available,
                  amount: currencyFormat.format(availableAmount),
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingMedium),
          ActionButton(
            text: isPayoutRequested
                ? t.dashboard.payoutRequested
                : t.dashboard.requestPayout,
            // ignore: dead_code
            icon: isPayoutRequested ? Icons.check : Icons.payments,
            onPressed: canRequest
                ? () {
                    // TODO: Implement Payout Request
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingMedium,
        vertical: AppSizes.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textBlack.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
        ],
      ),
    );
  }
}
