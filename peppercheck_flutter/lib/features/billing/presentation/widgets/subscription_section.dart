import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/app/utils/date_time_utils.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/domain/subscription_display_state.dart';
import 'package:peppercheck_flutter/features/billing/presentation/current_purchase_provider.dart';
import 'package:peppercheck_flutter/features/billing/presentation/in_app_purchase_controller.dart';
import 'package:peppercheck_flutter/features/billing/presentation/plan_utils.dart';
import 'package:peppercheck_flutter/features/billing/presentation/widgets/plan_card.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // Fetch current Google Play purchase for upgrade/downgrade flow.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inAppPurchaseControllerProvider.notifier).fetchCurrentPurchase();
    });
  }

  Future<void> _launchWebDashboard() async {
    final baseUrl =
        dotenv.env['WEB_DASHBOARD_URL'] ?? 'http://localhost:3000/dashboard';
    final url = Uri.parse(baseUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final purchaseState = ref.watch(inAppPurchaseControllerProvider);

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
              _StatusDisplay(displayState: displayState),

              if (purchaseState.value == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    t.billing.updatingPlan,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: AppSizes.spacingSmall),

              _PlanCardList(
                displayState: displayState,
                isProcessing: purchaseState.value == true,
              ),

              const SizedBox(height: AppSizes.spacingSmall),

              ActionButton(
                text: t.billing.manageSubscription,
                icon: Icons.open_in_new,
                onPressed: _launchWebDashboard,
              ),

              if (purchaseState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
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

class _StatusDisplay extends StatelessWidget {
  final SubscriptionDisplayState displayState;
  const _StatusDisplay({required this.displayState});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Icon(Icons.star, color: _iconColor, size: 32),
          const SizedBox(width: AppSizes.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(),
                if (_subtitle != null) ...[
                  const SizedBox(height: 4),
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
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      NotSubscribedWithPaymentIssue() => Text(
        '${t.billing.noPlan}（${t.billing.paymentIssue}）',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textError,
        ),
      ),
      ActiveSubscription(:final planId, :final cancelAtPeriodEnd) => Text(
        cancelAtPeriodEnd
            ? '${planName(planId)}（${t.billing.noAutoRenewal}）'
            : planName(planId),
        style: const TextStyle(fontWeight: FontWeight.bold),
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
      '${cancelAtPeriodEnd ? t.billing.periodEnd : t.billing.renews}: ${formatDate(periodEnd.toLocal())}',
    ActiveWithPaymentIssue(:final periodEnd) =>
      '${t.billing.renews}: ${formatDate(periodEnd.toLocal())}',
    NotSubscribed() => null,
    NotSubscribedWithPaymentIssue() => null,
  };
}

class _PlanCardList extends ConsumerWidget {
  final SubscriptionDisplayState displayState;
  final bool isProcessing;
  const _PlanCardList({required this.displayState, required this.isProcessing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(availableProductsProvider);

    return productsState.when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        final sorted = List<ProductDetails>.from(products)
          ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

        final currentPlanId = switch (displayState) {
          ActiveSubscription(:final planId) => planId,
          ActiveWithPaymentIssue(:final planId) => planId,
          NotSubscribed() => null,
          NotSubscribedWithPaymentIssue() => null,
        };

        final cards = <Widget>[];
        for (var i = 0; i < sorted.length; i++) {
          if (i > 0) cards.add(const SizedBox(height: AppSizes.spacingTiny));
          final product = sorted[i];
          final pId = productIdToPlanId(product.id);
          final isCurrent = pId == currentPlanId;
          cards.add(
            PlanCard(
              product: product,
              isCurrentPlan: isCurrent,
              onTap: (isCurrent || isProcessing)
                  ? null
                  : () => _onPlanTap(ref, product, currentPlanId),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  void _onPlanTap(
    WidgetRef ref,
    ProductDetails product,
    String? currentPlanId,
  ) {
    final controller = ref.read(inAppPurchaseControllerProvider.notifier);

    if (currentPlanId == null) {
      // New purchase (not subscribed)
      controller.buy(product: product);
      return;
    }

    // Plan change (upgrade/downgrade)
    final currentPurchase = ref.read(currentPurchaseProvider);
    final newPlanId = productIdToPlanId(product.id);
    final isUpgrade =
        (planOrder[newPlanId] ?? 0) > (planOrder[currentPlanId] ?? 0);

    controller.buy(
      product: product,
      oldPurchase: currentPurchase,
      isUpgrade: isUpgrade,
    );
  }
}
