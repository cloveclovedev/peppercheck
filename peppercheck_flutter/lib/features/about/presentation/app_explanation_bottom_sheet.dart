import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_bottom_sheet.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the shared "PepperCheckとは" concept-explanation BottomSheet.
Future<void> showAppExplanationBottomSheet(BuildContext context) {
  return showBaseBottomSheet<void>(
    context: context,
    title: t.appExplanation.sheetTitle,
    contentBuilder: (_) => const _AppExplanationBody(),
  );
}

class _ExplanationSection {
  final IconData icon;
  final String title;
  final String body;

  const _ExplanationSection({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _AppExplanationBody extends StatelessWidget {
  const _AppExplanationBody();

  @override
  Widget build(BuildContext context) {
    final sections = <_ExplanationSection>[
      _ExplanationSection(
        icon: Icons.flag_outlined,
        title: t.appExplanation.sections.concept.title,
        body: t.appExplanation.sections.concept.body,
      ),
      _ExplanationSection(
        icon: Icons.task_alt,
        title: t.appExplanation.sections.flow.title,
        body: t.appExplanation.sections.flow.body,
      ),
      _ExplanationSection(
        icon: Icons.workspace_premium,
        title: t.appExplanation.sections.points.title,
        body: t.appExplanation.sections.points.body,
      ),
      _ExplanationSection(
        icon: Icons.gavel,
        title: t.appExplanation.sections.referee.title,
        body: t.appExplanation.sections.referee.body,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.spacingStandard),
          _ExplanationSectionTile(section: sections[i]),
        ],
        const SizedBox(height: AppSizes.spacingStandard),
        const _LearnMoreLink(),
      ],
    );
  }
}

class _ExplanationSectionTile extends StatelessWidget {
  final _ExplanationSection section;

  const _ExplanationSectionTile({required this.section});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(section.icon, size: 24, color: AppColors.accentBlue),
        const SizedBox(width: AppSizes.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.spacingTiny),
              Text(
                section.body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearnMoreLink extends StatelessWidget {
  const _LearnMoreLink();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchUrl(
        Uri.parse('https://peppercheck.dev'),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingTiny),
        child: Text(
          t.appExplanation.learnMore,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
