import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_card.dart';
import 'package:peppercheck_flutter/features/billing/presentation/plan_utils.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the plan selection bottom sheet.
///
/// Returns the selected [ProductDetails] if the user picks a plan,
/// or `null` if dismissed.
Future<ProductDetails?> showPlanSelectionBottomSheet(
  BuildContext context, {
  required List<ProductDetails> products,
  required String? currentPlanId,
  required bool showCancelLink,
}) {
  return showModalBottomSheet<ProductDetails>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlanSelectionSheet(
      products: products,
      currentPlanId: currentPlanId,
      showCancelLink: showCancelLink,
    ),
  );
}

class _PlanSelectionSheet extends StatelessWidget {
  final List<ProductDetails> products;
  final String? currentPlanId;
  final bool showCancelLink;

  const _PlanSelectionSheet({
    required this.products,
    required this.currentPlanId,
    required this.showCancelLink,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<ProductDetails>.from(products)
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenHorizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSizes.spacingSmall),
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacingStandard),
              // Title
              Text(
                t.billing.planSelectionTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              // Plan cards
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSizes.baseCardGap),
                _buildPlanCard(context, sorted[i]),
              ],
              // Cancel link
              if (showCancelLink) ...[
                const SizedBox(height: AppSizes.spacingMedium),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => launchUrl(
                      Uri.parse(
                        'https://play.google.com/store/account/subscriptions',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spacingTiny,
                      ),
                      child: Text(
                        t.billing.cancelViaGooglePlay,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.spacingMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, ProductDetails product) {
    final planId = productIdToPlanId(product.id);
    final isCurrent = planId == currentPlanId;
    final color = planColor(planId);

    return BaseCard(
      backgroundColor: isCurrent
          ? AppColors.backgroundDark.withValues(alpha: 0.3)
          : null,
      onTap: isCurrent ? null : () => Navigator.of(context).pop(product),
      child: Row(
        children: [
          Icon(
            Icons.star,
            color: isCurrent ? AppColors.textMuted : color,
            size: AppSizes.baseCardIconSize,
          ),
          const SizedBox(width: AppSizes.baseCardIconGap),
          Expanded(
            child: Text(
              planName(planId),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrent ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
          if (isCurrent)
            Text(
              t.billing.currentPlan,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else
            Text(
              product.price,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accentBlue,
              ),
            ),
        ],
      ),
    );
  }
}
