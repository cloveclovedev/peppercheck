import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/colors.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class BillingSetupSection extends StatelessWidget {
  const BillingSetupSection({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch actual payment method status
    final bool hasPaymentMethod = false;

    return BaseSection(
      title: t.billing.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasPaymentMethod) ...[
            Text(
              t.billing.noPaymentMethod,
              style: TextStyle(
                color: AppColors.textBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            ActionButton(
              text: t.billing.addPaymentMethod,
              icon: Icons.credit_card,
              onPressed: () {
                // TODO: Implement Add Payment Method
              },
            ),
            /*
          ] else ...[
            // ignore: dead_code
            // TODO: Show existing payment method card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: AppColors.textBlack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visa **** 4242',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Expires 12/25',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Change Payment Method
                    },
                    child: Text(t.billing.changePaymentMethod),
                  ),
                ],
              ),
            ),
          */
          ],
        ],
      ),
    );
  }
}
