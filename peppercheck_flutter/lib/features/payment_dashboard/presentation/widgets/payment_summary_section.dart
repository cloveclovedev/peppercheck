import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_card.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/common_widgets/help_icon_button.dart';
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
    final hasTrial = summary.trialPoints != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Points area — trial and regular are mutually exclusive
        if (hasTrial) _buildTrialPointsRow() else _buildRegularPointsRow(),
        // Obligations card — independent of trial/regular points
        if (summary.obligationsRemaining > 0) ...[
          const SizedBox(height: AppSizes.baseCardGap),
          BaseCard(
            child: Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: AppColors.accentYellow,
                  size: AppSizes.baseCardIconSize,
                ),
                const SizedBox(width: AppSizes.baseCardIconGap),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.dashboard.pendingObligationsLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacingTiny),
                      HelpIconButton(
                        title: t.dashboard.pendingObligationsHelp.title,
                        body: t.dashboard.pendingObligationsHelp.body,
                      ),
                    ],
                  ),
                ),
                Text(
                  t.dashboard.obligationCount(
                    count: summary.obligationsRemaining,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentYellow,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Rewards row — only if rewards exist
        if (summary.rewards != null) ...[
          const SizedBox(height: AppSizes.baseCardGap),
          Row(
            children: [
              Expanded(
                child: BaseCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.textSecondary,
                        size: AppSizes.baseCardIconSize,
                      ),
                      const SizedBox(width: AppSizes.baseCardIconGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: _CardLabel(
                                    label: t.dashboard.rewardBalance,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.spacingTiny),
                                HelpIconButton(
                                  title: t.dashboard.rewardBalanceHelp.title,
                                  body: t.dashboard.rewardBalanceHelp.body,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _CardValue(
                              value: _formatCurrency(
                                summary.rewards!.amountMinor,
                                summary.rewards!.currencyCode,
                                summary.rewards!.currencyExponent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.baseCardGap),
              Expanded(
                child: BaseCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: AppColors.textSecondary,
                        size: AppSizes.baseCardIconSize,
                      ),
                      const SizedBox(width: AppSizes.baseCardIconGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: _CardLabel(
                                    label: t.dashboard.totalEarned,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.spacingTiny),
                                HelpIconButton(
                                  title: t.dashboard.totalEarnedHelp.title,
                                  body: t.dashboard.totalEarnedHelp.body,
                                ),
                              ],
                            ),
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
                ),
              ),
            ],
          ),
        ],
        // Payout info — conditional rows
        if (summary.recentPayout != null ||
            (summary.rewards != null && summary.rewards!.balance > 0)) ...[
          const SizedBox(height: AppSizes.baseCardGap),
          BaseCard(
            child: Row(
              children: [
                Icon(
                  Icons.send,
                  color: AppColors.textSecondary,
                  size: AppSizes.baseCardIconSize,
                ),
                const SizedBox(width: AppSizes.baseCardIconGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (summary.recentPayout != null) ...[
                        _PayoutRow(
                          label: t.dashboard.recentPayout,
                          value:
                              '${_formatCurrency(summary.recentPayout!.amountMinor, summary.recentPayout!.currencyCode, summary.recentPayout!.currencyExponent)} (${_payoutStatusLabel(summary.recentPayout!.status)}) — ${_formatDate(summary.recentPayout!.batchDate)}',
                        ),
                      ],
                      if (summary.recentPayout != null &&
                          summary.rewards != null &&
                          summary.rewards!.balance > 0)
                        const SizedBox(height: 4),
                      if (summary.rewards != null &&
                          summary.rewards!.balance > 0) ...[
                        _PayoutRow(
                          label: t.dashboard.nextPayout,
                          value: _formatDate(summary.nextPayoutDate),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Regular points card with toll icon
  Widget _buildRegularPointsRow() {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.toll,
                color: AppColors.accentGreen,
                size: AppSizes.baseCardIconSize,
              ),
              const SizedBox(width: AppSizes.baseCardIconGap),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.dashboard.availablePoints,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacingTiny),
                    HelpIconButton(
                      title: t.dashboard.availablePointsHelp.title,
                      body: t.dashboard.availablePointsHelp.body,
                    ),
                  ],
                ),
              ),
              Text(
                '${summary.points.available} pt',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGreen,
                ),
              ),
            ],
          ),
          if (summary.points.locked > 0) ...[
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.only(
                left: AppSizes.baseCardIconSize + AppSizes.baseCardIconGap,
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${t.dashboard.lockedPoints}: ${summary.points.locked} pt',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingTiny),
                  HelpIconButton(
                    title: t.dashboard.lockedPointsHelp.title,
                    body: t.dashboard.lockedPointsHelp.body,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Trial points card with star icon — same BaseCard default style, no colored background
  Widget _buildTrialPointsRow() {
    return BaseCard(
      child: Row(
        children: [
          Icon(
            Icons.stars,
            color: AppColors.accentGreen,
            size: AppSizes.baseCardIconSize,
          ),
          const SizedBox(width: AppSizes.baseCardIconGap),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    t.dashboard.trialPoints,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSizes.spacingTiny),
                HelpIconButton(
                  title: t.dashboard.trialPointsHelp.title,
                  body: t.dashboard.trialPointsHelp.body,
                ),
              ],
            ),
          ),
          Text(
            '${summary.trialPoints!.available} pt',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.accentGreen,
            ),
          ),
        ],
      ),
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

  static String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return DateFormat('yyyy/M/d').format(date);
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
