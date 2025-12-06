import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/payout/presentation/reward_summary_controller.dart';
import 'package:peppercheck_flutter/features/payout/presentation/widgets/payout_amount_dialog.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class RewardSummarySection extends ConsumerWidget {
  const RewardSummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(rewardSummaryControllerProvider);

    return BaseSection(
      title: t.dashboard.totalEarnings,
      child: stateAsync.when(
        data: (state) {
          final summary = state.summary;
          final currency = state.currency;
          final isRequesting = state.isRequestingPayout;

          // Currency formatting helper
          String formatCurrency(int minorAmount) {
            final double majorAmount = minorAmount / pow(10, currency.exponent);
            return NumberFormat.simpleCurrency(
              name: currency.code,
            ).format(majorAmount);
          }

          // TODO: Total earnings calculation is pending backend support
          final int totalEarnings = 0;

          final bool canRequest = summary.availableMinor > 0 && !isRequesting;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatCurrency(totalEarnings),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.spacingSmall),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: t.dashboard.pending,
                      amount: formatCurrency(summary.incomingPendingMinor),
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingMedium),
                  Expanded(
                    child: _SummaryItem(
                      label: t.dashboard.available,
                      amount: formatCurrency(summary.availableMinor),
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingSmall),
              ActionButton(
                text: t.dashboard.requestPayout,
                icon: Icons.payments,
                isLoading: isRequesting,
                onPressed: canRequest
                    ? () async {
                        await showDialog(
                          context: context,
                          builder: (context) => PayoutAmountDialog(
                            availableMinor: summary.availableMinor,
                            currency: currency,
                            onConfirm: (amount) {
                              ref
                                  .read(
                                    rewardSummaryControllerProvider.notifier,
                                  )
                                  .requestPayout(amount);
                            },
                          ),
                        );
                      }
                    : null,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.accentRed),
          ),
        ),
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
        border: Border.all(color: AppColors.border),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
