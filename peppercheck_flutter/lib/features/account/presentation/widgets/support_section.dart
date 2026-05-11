import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/about/presentation/app_explanation_bottom_sheet.dart';
import 'package:peppercheck_flutter/features/billing/data/billing_providers.dart';
import 'package:peppercheck_flutter/features/billing/presentation/in_app_purchase_controller.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportSection extends ConsumerWidget {
  const SupportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseSection(
      title: t.support.title,
      child: Column(
        children: [
          _LinkTile(
            title: t.support.aboutPeppercheck,
            onTap: () => showAppExplanationBottomSheet(context),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          _LinkTile(
            title: t.support.termsOfService,
            onTap: () => _launchLegalPage('terms'),
          ),
          const SizedBox(height: AppSizes.spacingSmall),
          _LinkTile(
            title: t.support.privacyPolicy,
            onTap: () => _launchLegalPage('privacy'),
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: AppSizes.spacingSmall),
            _LinkTile(
              title: t.billing.restorePurchases,
              onTap: () => _restorePurchases(context, ref),
            ),
          ],
          const SizedBox(height: AppSizes.spacingSmall),
          _LinkTile(
            title: t.support.contactUs,
            onTap: () => _launchUrl('mailto:hi@cloveclove.dev'),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(inAppPurchaseControllerProvider.notifier)
          .restorePurchases();
      ref.invalidate(subscriptionProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(t.billing.restoreSucceeded)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.billing.restoreFailed)));
    }
  }

  Future<void> _launchLegalPage(String page) async {
    // WEB_DASHBOARD_URL is expected to end with /dashboard (see .env.example)
    final dashboardUrl =
        dotenv.env['WEB_DASHBOARD_URL'] ?? 'http://localhost:3000/dashboard';
    final baseUrl = dashboardUrl.replaceAll(RegExp(r'/dashboard$'), '');
    final locale = LocaleSettings.currentLocale.languageCode;
    await _launchUrl('$baseUrl/$locale/legal/$page');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingTiny),
        child: Row(
          children: [
            Expanded(child: Text(title)),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
