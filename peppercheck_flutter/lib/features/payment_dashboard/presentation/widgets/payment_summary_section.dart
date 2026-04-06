import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/payment_dashboard/domain/payment_summary.dart';
import 'package:peppercheck_flutter/features/payment_dashboard/presentation/payment_summary_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PaymentSummarySection extends ConsumerWidget {
  const PaymentSummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(paymentSummaryControllerProvider);

    return BaseSection(
      title: t.dashboard.paymentSummary,
      child: stateAsync.when(
        data: (summary) => _SummaryContent(summary: summary),
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

class _SummaryContent extends StatelessWidget {
  final PaymentSummary summary;

  const _SummaryContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Points card — always shown
        _SummaryCard(
          children: [
            _IconRow(
              icon: Icons.circle,
              iconColor: AppColors.accentGreen,
              iconSize: 8,
              label: t.dashboard.availablePoints,
              value: '${summary.points.available} pt',
            ),
            if (summary.points.locked > 0) ...[
              const SizedBox(height: 4),
              _IconRow(
                icon: Icons.lock_outline,
                iconColor: AppColors.textSecondary,
                iconSize: 14,
                label: t.dashboard.lockedPoints,
                value: '${summary.points.locked} pt',
              ),
            ],
          ],
        ),
        // Trial points card — only if active
        if (summary.trialPoints != null) ...[
          const SizedBox(height: AppSizes.spacingSmall),
          _SummaryCard(
            backgroundColor: AppColors.accentGreenLight.withValues(alpha: 0.3),
            borderColor: AppColors.accentGreen.withValues(alpha: 0.5),
            children: [
              _IconRow(
                icon: Icons.stars,
                iconColor: AppColors.accentGreen,
                iconSize: 20,
                label: t.dashboard.trialPoints,
                value: '${summary.trialPoints!.available} pt',
              ),
            ],
          ),
        ],
        // Obligations card — only if remaining > 0
        if (summary.obligationsRemaining > 0) ...[
          const SizedBox(height: AppSizes.spacingSmall),
          _SummaryCard(
            backgroundColor: AppColors.accentYellowLight.withValues(alpha: 0.3),
            borderColor: AppColors.accentYellow.withValues(alpha: 0.5),
            children: [
              _IconRow(
                icon: Icons.assignment_outlined,
                iconColor: AppColors.accentYellow,
                iconSize: 20,
                label: t.dashboard.pendingObligations(
                  count: summary.obligationsRemaining,
                ),
                value: '',
              ),
            ],
          ),
        ],
        // Rewards row — only if rewards exist
        if (summary.rewards != null) ...[
          const SizedBox(height: AppSizes.spacingSmall),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  children: [
                    _CardLabel(label: t.dashboard.rewardBalance),
                    const SizedBox(height: 4),
                    _CardValue(
                      value:
                          '${summary.rewards!.balance} pt (${_formatCurrency(summary.rewards!.amountMinor, summary.rewards!.currencyCode, summary.rewards!.currencyExponent)})',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spacingMedium),
              Expanded(
                child: _SummaryCard(
                  children: [
                    _CardLabel(label: t.dashboard.totalEarned),
                    const SizedBox(height: 4),
                    _CardValue(
                      value: summary.totalEarnedCurrency != null
                          ? _formatCurrency(
                              summary.totalEarnedMinor,
                              summary.totalEarnedCurrency!,
                              summary.rewards!.currencyExponent,
                            )
                          : '—',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        // Payout info — conditional rows
        if (summary.recentPayout != null ||
            (summary.rewards != null && summary.rewards!.balance > 0)) ...[
          const SizedBox(height: AppSizes.spacingSmall),
          _SummaryCard(
            children: [
              if (summary.recentPayout != null) ...[
                _PayoutRow(
                  label: t.dashboard.recentPayout,
                  value:
                      '${_formatCurrency(summary.recentPayout!.amountMinor, summary.recentPayout!.currencyCode, summary.recentPayout!.currencyExponent)} (${_payoutStatusLabel(summary.recentPayout!.status)}) — ${summary.recentPayout!.batchDate}',
                ),
              ],
              if (summary.recentPayout != null &&
                  summary.rewards != null &&
                  summary.rewards!.balance > 0)
                const SizedBox(height: 4),
              if (summary.rewards != null && summary.rewards!.balance > 0) ...[
                _PayoutRow(
                  label: t.dashboard.nextPayout,
                  value: summary.nextPayoutDate,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  static String _formatCurrency(
    int amountMinor,
    String currencyCode,
    int exponent,
  ) {
    final double majorAmount = amountMinor / pow(10, exponent);
    return NumberFormat.simpleCurrency(name: currencyCode).format(majorAmount);
  }

  static String _payoutStatusLabel(String status) {
    switch (status) {
      case 'success':
        return t.dashboard.payoutStatusSuccess;
      case 'pending':
        return t.dashboard.payoutStatusPending;
      case 'failed':
        return t.dashboard.payoutStatusFailed;
      case 'skipped':
        return t.dashboard.payoutStatusSkipped;
      default:
        return status;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final List<Widget> children;
  final Color? backgroundColor;
  final Color? borderColor;

  const _SummaryCard({
    required this.children,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingMedium,
        vertical: AppSizes.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;
  final String value;

  const _IconRow({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        if (value.isNotEmpty) ...[
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}

class _CardLabel extends StatelessWidget {
  final String label;
  const _CardLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _CardValue extends StatelessWidget {
  final String value;
  const _CardValue({required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  final String label;
  final String value;
  const _PayoutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
