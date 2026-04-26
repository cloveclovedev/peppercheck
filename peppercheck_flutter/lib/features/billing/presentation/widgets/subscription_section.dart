import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/app/utils/date_time_utils.dart';
import 'package:peppercheck_flutter/common_widgets/base_card.dart';
import 'package:peppercheck_flutter/common_widgets/base_card_action.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/domain/subscription_display_state.dart';
import 'package:peppercheck_flutter/features/billing/presentation/current_purchase_provider.dart';
import 'package:peppercheck_flutter/features/billing/presentation/in_app_purchase_controller.dart';
import 'package:peppercheck_flutter/features/billing/presentation/plan_utils.dart';
import 'package:peppercheck_flutter/features/billing/presentation/widgets/plan_selection_bottom_sheet.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class SubscriptionSection extends ConsumerStatefulWidget {
  const SubscriptionSection({super.key});

  @override
  ConsumerState<SubscriptionSection> createState() =>
      _SubscriptionSectionState();
}

class _SubscriptionSectionState extends ConsumerState<SubscriptionSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inAppPurchaseControllerProvider.notifier).fetchCurrentPurchase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final purchaseState = ref.watch(inAppPurchaseControllerProvider);
    // Pre-warm product list so it's ready when the user taps the CTA.
    ref.watch(availableProductsProvider);

    return BaseSection(
      title: t.billing.subscription,
      child: subscriptionAsync.when(
        data: (subscription) {
          final displayState = SubscriptionDisplayState.fromSubscription(
            subscription,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SubscriptionStatusCard(displayState: displayState),
              if (purchaseState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSizes.spacingSmall),
                  child: Text(
                    'Purchase Error: ${purchaseState.error}',
                    style: const TextStyle(color: AppColors.textError),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Text(
          'Error: $e',
          style: const TextStyle(color: AppColors.textError),
        ),
      ),
    );
  }
}

class _SubscriptionStatusCard extends ConsumerWidget {
  final SubscriptionDisplayState displayState;
  const _SubscriptionStatusCard({required this.displayState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseCard(
      child: Row(
        children: [
          Icon(Icons.star, color: _iconColor, size: AppSizes.baseCardIconSize),
          const SizedBox(width: AppSizes.baseCardIconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(),
                if (_subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.baseCardIconGap),
          BaseCardAction(
            label: _ctaLabel,
            color: _ctaColor,
            onPressed: () => _onCtaTap(context, ref),
          ),
        ],
      ),
    );
  }

  Color get _iconColor => switch (displayState) {
    ActiveSubscription(:final planId) => planColor(planId),
    ActiveWithPaymentIssue(:final planId) => planColor(planId),
    NotSubscribed() => AppColors.textMuted,
    NotSubscribedWithPaymentIssue() => AppColors.textMuted,
  };

  Widget _buildTitle() {
    return switch (displayState) {
      NotSubscribed() => Text(
        t.billing.noPlan,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      NotSubscribedWithPaymentIssue() => Text(
        '${t.billing.noPlan}（${t.billing.paymentIssue}）',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textError,
        ),
      ),
      ActiveSubscription(:final planId) => Text(
        planName(planId),
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      ActiveWithPaymentIssue(:final planId) => Text(
        '${planName(planId)}（${t.billing.paymentIssue}）',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textError,
        ),
      ),
    };
  }

  String? get _subtitle => switch (displayState) {
    ActiveSubscription(:final periodEnd, :final cancelAtPeriodEnd) =>
      cancelAtPeriodEnd
          ? t.billing.canceledUntil(date: formatDate(periodEnd.toLocal()))
          : '${t.billing.renews}: ${formatDate(periodEnd.toLocal())}',
    ActiveWithPaymentIssue(:final periodEnd) =>
      '${t.billing.renews}: ${formatDate(periodEnd.toLocal())}',
    NotSubscribed() => null,
    NotSubscribedWithPaymentIssue() => null,
  };

  String get _ctaLabel => switch (displayState) {
    NotSubscribed() => t.billing.choosePlan,
    NotSubscribedWithPaymentIssue() => t.billing.checkPlan,
    ActiveSubscription() => t.billing.changePlan,
    ActiveWithPaymentIssue() => t.billing.checkPlan,
  };

  Color get _ctaColor => switch (displayState) {
    NotSubscribedWithPaymentIssue() => AppColors.textError,
    ActiveWithPaymentIssue() => AppColors.textError,
    _ => AppColors.accentBlue,
  };

  Future<void> _onCtaTap(BuildContext context, WidgetRef ref) async {
    final productsAsync = ref.read(availableProductsProvider);
    final products = productsAsync.value;
    if (products == null || products.isEmpty) return;

    final currentPlanId = switch (displayState) {
      ActiveSubscription(:final planId) => planId,
      ActiveWithPaymentIssue(:final planId) => planId,
      NotSubscribed() => null,
      NotSubscribedWithPaymentIssue() => null,
    };

    final showCancelLink =
        displayState is ActiveSubscription ||
        displayState is ActiveWithPaymentIssue;

    final selected = await showPlanSelectionBottomSheet(
      context,
      products: products,
      currentPlanId: currentPlanId,
      showCancelLink: showCancelLink,
    );

    if (selected == null) return;

    final controller = ref.read(inAppPurchaseControllerProvider.notifier);

    if (currentPlanId == null) {
      controller.buy(product: selected);
      return;
    }

    // Plan change (upgrade/downgrade)
    final currentPurchase = ref.read(currentPurchaseProvider);
    final newPlanId = productIdToPlanId(selected.id);
    final isUpgrade =
        (planOrder[newPlanId] ?? 0) > (planOrder[currentPlanId] ?? 0);

    controller.buy(
      product: selected,
      oldPurchase: currentPurchase,
      isUpgrade: isUpgrade,
    );
  }
}
