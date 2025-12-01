import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/payout/presentation/payout_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PayoutSetupSection extends ConsumerStatefulWidget {
  const PayoutSetupSection({super.key});

  @override
  ConsumerState<PayoutSetupSection> createState() => _PayoutSetupSectionState();
}

class _PayoutSetupSectionState extends ConsumerState<PayoutSetupSection> {
  bool _showHints = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payoutControllerProvider);

    return BaseSection(
      title: t.payout.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.value?.isComplete == true) ...[
            Text(
              t.payout.payoutSetupComplete,
              style: TextStyle(
                color: AppColors.textBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSizes.spacingMedium),
            ActionButton(
              text: t.payout.changePayoutSettings,
              icon: Icons.settings,
              isLoading: state.isLoading,
              onPressed: () {
                ref.read(payoutControllerProvider.notifier).setupPayout();
              },
            ),
          ] else ...[
            if (state.value?.isInProgress == true)
              Text(
                t.payout.payoutSetupInProgressDescription,
                style: TextStyle(
                  color: AppColors.textBlack.withValues(alpha: 0.6),
                ),
              )
            else
              Text(
                t.payout.payoutSetupDescription,
                style: TextStyle(
                  color: AppColors.textBlack.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(height: AppSizes.spacingMedium),
            ActionButton(
              text: state.value?.isInProgress == true
                  ? t.payout.resumeSetup
                  : t.payout.setupPayout,
              icon: Icons.account_balance,
              isLoading: state.isLoading,
              onPressed: () {
                ref.read(payoutControllerProvider.notifier).setupPayout();
              },
            ),
            const SizedBox(height: AppSizes.spacingSmall),
            InkWell(
              onTap: () {
                setState(() {
                  _showHints = !_showHints;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0),
                child: Text(
                  _showHints
                      ? '▲ ${t.payout.hideHints}'
                      : '▼ ${t.payout.showHints}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textBlack.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            if (_showHints) ...[
              const SizedBox(height: AppSizes.spacingSmall),
              _buildHintItem(context, t.payout.hintIndustry),
              const SizedBox(height: AppSizes.spacingTiny),
              _buildHintItem(
                context,
                t.payout.hintDescription,
                copyText: t.payout.hintDescriptionCopy,
              ),
              const SizedBox(height: AppSizes.spacingTiny),
              _buildHintItem(
                context,
                t.payout.hintWebsite,
                copyText: t.payout.hintWebsiteCopy,
              ),
            ],
          ],
          if (state.hasError) ...[
            const SizedBox(height: AppSizes.spacingSmall),
            Text(
              state.error.toString(),
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHintItem(BuildContext context, String text, {String? copyText}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingSmall),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: _buildBoldText(
                context,
                text,
                AppColors.textBlack.withValues(alpha: 0.7),
              ),
            ),
          ),
          if (copyText != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: copyText));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.payout.copiedInputExample)),
                  );
                }
              },
              child: Icon(
                Icons.copy,
                size: 14,
                color: AppColors.textBlack.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextSpan _buildBoldText(BuildContext context, String text, Color color) {
    final regex = RegExp(r'「(.*?)」');
    final matches = regex.allMatches(text);
    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color, fontSize: 10),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: '「${match.group(1)}」',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: color, fontSize: 10),
        ),
      );
    }

    return TextSpan(children: spans);
  }
}
