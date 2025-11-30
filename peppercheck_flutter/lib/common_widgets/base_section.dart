import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/colors.dart';

class BaseSection extends StatelessWidget {
  final String title;
  final Widget child;

  const BaseSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.backgroundLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textBlack,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textBlack),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
