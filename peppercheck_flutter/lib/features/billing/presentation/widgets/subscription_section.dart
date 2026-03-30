import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/action_button.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/presentation/in_app_purchase_controller.dart';
import 'package:peppercheck_flutter/app/utils/date_time_utils.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionSection extends ConsumerWidget {
  const SubscriptionSection({super.key});

  Future<void> _launchWebDashboard() async {
    final baseUrl =
        dotenv.env['WEB_DASHBOARD_URL'] ?? 'http://localhost:3000/dashboard';
    final url = Uri.parse(baseUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  String _getPlanName(String? planId) {
    if (planId == 'light') return t.billing.plans.light;
    if (planId == 'standard') return t.billing.plans.standard;
    if (planId == 'premium') return t.billing.plans.premium;
    return t.billing.noPlan;
  }

  Color _getPlanColor(String? planId) {
    if (planId == 'light') return AppColors.accentGreen;
    if (planId == 'standard') return AppColors.accentBlue;
    if (planId == 'premium') return AppColors.accentYellow;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final purchaseState = ref.watch(inAppPurchaseControllerProvider);

    final isPurchasing = purchaseState.isLoading;

    return Stack(
      children: [
        BaseSection(
          title: t.billing.subscription,
          child: state.when(
            data: (subscription) {
              final status = subscription?.status;
              final planId = subscription?.planId;
              final expiry = subscription?.currentPeriodEnd;
              final bool isActive = status == 'active';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacingMedium,
                      vertical: AppSizes.spacingSmall,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: _getPlanColor(planId),
                          size: 32,
                        ),
                        const SizedBox(width: AppSizes.spacingMedium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getPlanName(planId),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if ((status != null && !isActive) ||
                                  expiry != null) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    if (status != null && !isActive)
                                      Text(
                                        status,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (expiry != null)
                                      Text(
                                        '${t.billing.renews}: ${formatDate(DateTime.parse(expiry).toLocal())}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingSmall),

                  if (!isActive) ...[
                    const _ProductList(),
                    const SizedBox(height: AppSizes.spacingSmall),
                  ],

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
        ),
        if (isPurchasing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSizes.spacingMedium),
                    Text(
                      t.billing.processingPurchase,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(availableProductsProvider);

    return productsState.when(
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort by price ascending (light < standard < premium)
        final sorted = List<ProductDetails>.from(products)
          ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sorted.map((product) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacingSmall),
              child: _ProductCard(product: product),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductDetails product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(AppSizes.spacingMedium),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
      ),
      onPressed: () {
        ref
            .read(inAppPurchaseControllerProvider.notifier)
            .buy(product: product);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              product.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
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
