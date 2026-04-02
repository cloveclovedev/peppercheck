import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// Maps a Google Play product ID to the corresponding plan ID.
/// e.g. 'light_monthly' → 'light'
String productIdToPlanId(String productId) {
  return productId.replaceAll('_monthly', '');
}

/// Returns the i18n plan name for a given plan ID.
String planName(String planId) {
  return switch (planId) {
    'light' => t.billing.plans.light,
    'standard' => t.billing.plans.standard,
    'premium' => t.billing.plans.premium,
    _ => planId,
  };
}

/// Returns the accent color for a given plan ID.
Color planColor(String planId) {
  return switch (planId) {
    'light' => AppColors.accentGreen,
    'standard' => AppColors.accentBlue,
    'premium' => AppColors.accentYellow,
    _ => AppColors.textMuted,
  };
}

/// Plan order for upgrade/downgrade determination.
const planOrder = {'light': 0, 'standard': 1, 'premium': 2};
