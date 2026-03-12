import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class TrialPointWalletSection extends ConsumerWidget {
  const TrialPointWalletSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialWalletAsync = ref.watch(trialPointWalletProvider);
    final obligationsAsync = ref.watch(pendingObligationsProvider);

    return trialWalletAsync.when(
      data: (trialWallet) {
        if (trialWallet == null || !trialWallet.isActive) {
          return const SizedBox.shrink();
        }

        final availableTrialPoints = trialWallet.balance - trialWallet.locked;

        return BaseSection(
          title: t.billing.trialSectionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacingMedium,
                  vertical: AppSizes.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGreenLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars,
                      color: AppColors.accentGreen,
                      size: 24,
                    ),
                    const SizedBox(width: AppSizes.spacingSmall),
                    Text(
                      t.billing.trialPoints(count: availableTrialPoints),
                      style: const TextStyle(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              obligationsAsync.when(
                data: (obligations) {
                  final pendingCount = obligations.length;
                  if (pendingCount == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSizes.spacingSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacingMedium,
                        vertical: AppSizes.spacingSmall,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellowLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        border: Border.all(color: AppColors.accentYellow.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            color: AppColors.accentYellow,
                            size: 24,
                          ),
                          const SizedBox(width: AppSizes.spacingSmall),
                          Text(
                            t.billing.pendingObligations(count: pendingCount),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
