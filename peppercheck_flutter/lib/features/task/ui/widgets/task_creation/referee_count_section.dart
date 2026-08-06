import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// Picks how many referees to request when publishing: 1..[maxCount], where
/// the maximum comes from the server's matching config. While the config is
/// still loading the selector is disabled and shows 1, and once a smaller
/// maximum arrives a larger stale selection is clamped down — the server would
/// reject it otherwise. No point cost is shown; billing is not part of this
/// phase.
class RefereeCountSection extends StatelessWidget {
  const RefereeCountSection({
    super.key,
    required this.selected,
    required this.maxCount,
    required this.onChanged,
    required this.loading,
  });

  final int selected;
  final int maxCount;
  final ValueChanged<int> onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // Never fall below one option, even if the server ever reported a maximum
    // below 1: clamp() throws when its bounds cross.
    final upperBound = maxCount < 1 ? 1 : maxCount;
    final effective = loading ? 1 : selected.clamp(1, upperBound);
    if (!loading && effective != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(effective));
    }

    return BaseSection(
      title: t.task.creation.sectionRefereeCount,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var count = 1; count <= upperBound; count++) ...[
                if (count > 1)
                  const SizedBox(width: AppSizes.gapTaskStatusSelectorButton),
                Expanded(
                  child: _CountButton(
                    count: count,
                    isSelected: count == effective,
                    onTap: loading ? null : () => onChanged(count),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          Text(
            t.task.creation.refereeCountNotice,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.accentYellow
            : AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.taskStatusSelectorButtonBorderRadius,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.taskStatusSelectorButtonVerticalPadding,
        ),
      ),
      child: Text(
        t.task.creation.refereeCountUnit(count: count),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
