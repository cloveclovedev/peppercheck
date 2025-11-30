import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/colors.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PayoutSetupSection extends StatelessWidget {
  const PayoutSetupSection({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch actual payout setup status
    final bool isPayoutSetupComplete = false;

    return BaseSection(
      title: t.payout.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isPayoutSetupComplete) ...[
            Text(
              t.payout.payoutSetupDescription,
              style: TextStyle(
                color: AppColors.textBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            ActionButton(
              text: t.payout.setupPayout,
              icon: Icons.account_balance,
              onPressed: () {
                // TODO: Implement Payout Setup (Stripe Connect)
              },
            ),
          ],
        ],
      ),
    );
  }
}
