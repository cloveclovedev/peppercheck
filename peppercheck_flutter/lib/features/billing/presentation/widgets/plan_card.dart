import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/features/billing/presentation/plan_utils.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PlanCard extends StatelessWidget {
  final ProductDetails product;
  final bool isCurrentPlan;
  final VoidCallback? onTap;

  const PlanCard({
    super.key,
    required this.product,
    required this.isCurrentPlan,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pId = productIdToPlanId(product.id);
    final color = planColor(pId);
    final name = planName(pId);

    if (isCurrentPlan) {
      return _buildCard(
        context,
        color: color,
        name: name,
        isCurrentPlan: isCurrentPlan,
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.3),
        onTap: null,
        trailing: Text(
          t.billing.currentPlan,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    return _buildCard(
      context,
      color: color,
      name: name,
      isCurrentPlan: isCurrentPlan,
      backgroundColor: AppColors.backgroundWhite,
      onTap: onTap,
      trailing: Text(
        product.price,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.accentBlue,
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required Color color,
    required String name,
    required bool isCurrentPlan,
    required Color backgroundColor,
    required VoidCallback? onTap,
    required Widget trailing,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: backgroundColor,
        disabledForegroundColor: AppColors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
      ),
      child: Row(
        children: [
          Icon(
            Icons.star,
            color: isCurrentPlan ? AppColors.textMuted : color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrentPlan
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
