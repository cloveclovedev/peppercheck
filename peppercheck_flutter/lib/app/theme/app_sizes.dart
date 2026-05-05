class AppSizes {
  static const double spacingMicro = 2.0;
  static const double spacingTiny = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingStandard = 16.0;
  static const double spacingLarge = 24.0;

  // Section gap reduced to 8.0 as per user request
  static const double sectionGap = 8.0;
  static const double buttonGap = 12.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;

  // Semantic sizes
  static const double screenHorizontalPadding = 16.0;
  static const double screenVerticalPadding = 4.0;
  // Height of the floating navigation bar container + padding
  static const double bottomNavigationBarHeight = 80.0;
  static const double bottomNavigationBarBorderRadius = 16.0;
  // Breathing room below the floating bottom navigation bar, applied
  // on top of the system safe-area inset. Keeps a visible gap above
  // the system nav strip (Android 3-button bar, gesture indicator,
  // iOS home indicator) and a non-cramped margin from the screen edge
  // on devices with no inset (iOS home button).
  static const double bottomNavigationBarBreathingRoom = 8.0;

  // BaseSection
  static const double baseSectionHorizontalPadding = 12.0;
  static const double baseSectionTopPadding = 12.0;
  static const double baseSectionBottomPadding = 12.0;
  static const double baseSectionTitleBodyGap = 8.0;
  static const double baseSectionBorderRadius = 16.0;

  // BaseCard
  static const double baseCardGap = 4.0;
  static const double baseCardBorderRadius = 12.0;
  static const double baseCardPaddingHorizontal = 12.0;
  static const double baseCardPaddingVertical = 4.0;
  static const double baseCardIconSize = 20.0;
  static const double baseCardIconGap = 12.0;

  // Profile header avatar. 48dp fits neatly inside a BaseCard row while
  // remaining visually distinct from the 20dp baseCardIconSize.
  static const double avatarSizeLarge = 36.0;

  // Mid-size avatar used in task detail referee/requester cards.
  static const double avatarSizeMedium = 24.0;

  // Width of the white ring around overlapping avatars in a stack.
  static const double avatarStackRingWidth = 1.0;

  // Task Card specific
  static const double taskCardTitleInfoGap = 2.0;
  static const double taskCardStatusGap = 8.0;

  static const double gapTaskStatusSelector = 8.0;
  static const double gapTaskStatusSelectorButton = 8.0;
  static const double taskStatusSelectorIconSize = 16.0;
  static const double taskStatusSelectorButtonBorderRadius = 12.0;
  static const double taskStatusSelectorButtonVerticalPadding = 12.0;

  // Matching strategy
  static const double matchingStrategyTitleButtonGap = 4.0;
  static const double matchingStrategyButtonGap = 8.0;
  static const double matchingStrategyButtonHeight = 36.0;
  static const double matchingStrategyButtonIconSize = 16.0;
  static const double matchingStrategyButtonBorderRadius = 8.0;
  static const double matchingStrategyButtonHorizontalPadding = 12.0;

  static const double strategyButtonHorizontalPadding = 12.0;
  static const double strategyButtonVerticalPadding = 8.0;
  static const double strategyButtonBorderRadius = 8.0;

  static const double loginScreenHorizontalPadding = 32.0;
  static const double loginPeppercheckIconHeight = 140.0;
  static const double loginPeppercheckTitleFontSize = 48.0;

  // Referee Availability Section
  static const double timeSlotCardGap = 4.0;
  static const double timeSlotCardBorderRadius = 12.0;
  static const double timeSlotCardHorizontalPadding = 12.0;
  static const double timeSlotCardVerticalPadding = 4.0;
  static const double timeSlotCardAddButtonGap = 8.0;
  static const double timeSlotCardIconSize = 18.0;
  static const double timeSlotCardIconPadding = 6.0;
}
