import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/features/billing/presentation/widgets/billing_setup_section.dart';
import 'package:peppercheck_flutter/features/payout/presentation/widgets/payout_setup_section.dart';
import 'package:peppercheck_flutter/features/payout/presentation/widgets/reward_summary_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PaymentDashboardScreen extends ConsumerWidget {
  const PaymentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(
      child: AppScaffold(
        title: t.nav.payments,
        currentIndex: 1, // Payments is index 1
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const BillingSetupSection(),
                    const SizedBox(height: AppSizes.sectionGap),
                    const PayoutSetupSection(),
                    const SizedBox(height: AppSizes.sectionGap),
                    const RewardSummarySection(),
                    const SizedBox(height: 80), // Bottom padding
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
