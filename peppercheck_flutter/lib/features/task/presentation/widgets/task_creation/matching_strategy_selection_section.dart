import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/strategy_button.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class MatchingStrategySelectionSection extends ConsumerWidget {
  final List<String> selectedStrategies;
  final ValueChanged<List<String>> onStrategiesChange;

  const MatchingStrategySelectionSection({
    super.key,
    required this.selectedStrategies,
    required this.onStrategiesChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costAsync = ref.watch(matchingStrategyCostProvider('standard'));

    return BaseSection(
      title: t.task.creation.sectionMatching,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.matchingStrategyTitleButtonGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ...selectedStrategies.map((strategy) {
                final label = strategy == 'standard'
                    ? t.task.creation.strategy.standard
                    : strategy;

                return Padding(
                  padding: const EdgeInsets.only(
                    right: AppSizes.matchingStrategyButtonGap,
                  ),
                  child: StrategyButton(
                    label: label,
                    onRemove: () {
                      final newList = List<String>.from(selectedStrategies);
                      newList.remove(strategy);
                      onStrategiesChange(newList);
                    },
                  ),
                );
              }),
              if (selectedStrategies.length < 2)
                SizedBox(
                  height: AppSizes.matchingStrategyButtonHeight,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final newList = List<String>.from(selectedStrategies);
                      newList.add('standard');
                      onStrategiesChange(newList);
                    },
                    icon: const Icon(
                      Icons.add,
                      size: AppSizes.matchingStrategyButtonIconSize,
                    ),
                    label: Text(t.task.creation.buttonAdd),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentBlueLight,
                      side: const BorderSide(color: AppColors.accentBlueLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.matchingStrategyButtonBorderRadius,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal:
                            AppSizes.matchingStrategyButtonHorizontalPadding,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              costAsync.when(
                data: (costPerPlan) {
                  final totalPoints = selectedStrategies.length * costPerPlan;
                  return Text(
                    '${totalPoints}pt',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
                loading: () => Text(
                  '--pt',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                error: (_, _) => Text(
                  '--pt',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
