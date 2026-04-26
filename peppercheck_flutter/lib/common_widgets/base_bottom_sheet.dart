import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';

/// Shows a modal bottom sheet that uses the app's standard visual shell:
/// drag handle, title, screen-edge padding, keyboard + home-indicator
/// inset handling, and scroll-safe content. Callers do not manage MediaQuery.
Future<T?> showBaseBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext) contentBuilder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _BaseBottomSheetShell(
      title: title,
      content: contentBuilder(sheetContext),
    ),
  );
}

class _BaseBottomSheetShell extends StatelessWidget {
  final String title;
  final Widget content;

  const _BaseBottomSheetShell({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenHorizontalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSizes.spacingSmall),
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacingStandard),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.spacingMedium),
              content,
              const SizedBox(height: AppSizes.spacingMedium),
            ],
          ),
        ),
      ),
    );
  }
}
