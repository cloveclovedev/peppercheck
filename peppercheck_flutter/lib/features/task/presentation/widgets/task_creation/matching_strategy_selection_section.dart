import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_creation/strategy_button.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class MatchingStrategySelectionSection extends StatelessWidget {
  final List<String> selectedStrategies;
  final ValueChanged<List<String>> onStrategiesChange;

  const MatchingStrategySelectionSection({
    super.key,
    required this.selectedStrategies,
    required this.onStrategiesChange,
  });

  @override
  Widget build(BuildContext context) {
    final totalFee = selectedStrategies.length * 50;

    return BaseSection(
      title: t.task.creation.sectionMatching,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 4), // Add spacing between title and content
          Row(
            children: [
              ...selectedStrategies.map((strategy) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: StrategyButton(
                    strategy: strategy,
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
                  height: 36, // Match typical chip height
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final newList = List<String>.from(selectedStrategies);
                      newList.add('standard');
                      onStrategiesChange(newList);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(t.task.creation.buttonAdd),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentBlueLight,
                      side: const BorderSide(color: AppColors.accentBlueLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '¥$totalFee',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
