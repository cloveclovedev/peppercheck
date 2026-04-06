import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/features/billing/presentation/widgets/subscription_section.dart';
import 'package:peppercheck_flutter/features/payment_dashboard/presentation/widgets/payment_summary_section.dart';
import 'package:peppercheck_flutter/features/payout/presentation/widgets/payout_setup_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PaymentDashboardScreen extends ConsumerWidget {
  const PaymentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(
      child: AppScaffold.scrollable(
        title: t.nav.payments,
        currentIndex: 1,
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              const PaymentSummarySection(),
              const SizedBox(height: AppSizes.sectionGap),
              const SubscriptionSection(),
              const SizedBox(height: AppSizes.sectionGap),
              const PayoutSetupSection(),
            ]),
          ),
        ],
      ),
    );
  }
}
