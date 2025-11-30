import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/billing/presentation/billing_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class BillingSetupSection extends ConsumerWidget {
  const BillingSetupSection({super.key});

  IconData _getBrandIcon(String? brand) {
    switch (brand?.toLowerCase()) {
      case 'visa':
        return FontAwesomeIcons.ccVisa;
      case 'mastercard':
        return FontAwesomeIcons.ccMastercard;
      case 'amex':
      case 'american express':
        return FontAwesomeIcons.ccAmex;
      case 'discover':
        return FontAwesomeIcons.ccDiscover;
      case 'diners club':
      case 'diners':
        return FontAwesomeIcons.ccDinersClub;
      case 'jcb':
        return FontAwesomeIcons.ccJcb;
      case 'unionpay':
        return FontAwesomeIcons
            .ccStripe; // No specific UnionPay in FA free? Use generic or Stripe
      default:
        return FontAwesomeIcons.creditCard;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);

    ref.listen(billingControllerProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return BaseSection(
      title: t.billing.paymentMethod,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.value?.hasPaymentMethod == true) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacingMedium,
                vertical: AppSizes.spacingSmall,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    _getBrandIcon(state.value!.brand),
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                  const SizedBox(width: AppSizes.spacingMedium),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•••• ${state.value!.last4}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Expires: ${state.value!.expMonth}/${state.value!.expYear}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacingSmall),
            ActionButton(
              text: t.billing.changePaymentMethod,
              icon: Icons.credit_card,
              isLoading: state.isLoading,
              onPressed: () async {
                await ref
                    .read(billingControllerProvider.notifier)
                    .setupPaymentMethod();
                if (context.mounted &&
                    !ref.read(billingControllerProvider).hasError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.billing.paymentMethodAdded)),
                  );
                }
              },
            ),
          ] else ...[
            Text(
              t.billing.noPaymentMethod,
              style: TextStyle(
                color: AppColors.textBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSizes.spacingMedium),
            ActionButton(
              text: t.billing.addPaymentMethod,
              icon: Icons.credit_card,
              isLoading: state.isLoading,
              onPressed: () async {
                await ref
                    .read(billingControllerProvider.notifier)
                    .setupPaymentMethod();
                if (context.mounted &&
                    !ref.read(billingControllerProvider).hasError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.billing.paymentMethodAdded)),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
