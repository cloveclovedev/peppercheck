# Flutter UI guidelines

Status: Current implementation guide. The applicable `AGENTS.md` remains the
authoritative source for agent rules.

## Screen structure

- Use `AppScaffold.scrollable` for standard internal screens.
- Supply slivers directly. Wrap non-list content in `SliverToBoxAdapter`.
- Use `AppScaffold.fixed` for zero-padding or deliberately custom layouts such
  as maps and full-screen media.
- When using the fixed constructor, account explicitly for safe areas, page
  padding, scrolling, and the floating bottom navigation bar.

## Spacing and layout

Use semantic constants from `AppSizes`. Current shared values include:

- screen horizontal padding: `AppSizes.screenHorizontalPadding`
- screen vertical padding: `AppSizes.screenVerticalPadding`
- section gap: `AppSizes.sectionGap`
- shared section padding and radius: the `AppSizes.baseSection*` constants
- shared card padding and radius: the `AppSizes.baseCard*` constants

Avoid raw numeric spacing in feature widgets. Add a descriptively named
constant when the existing semantic values do not express the layout.

## Color and typography

Use `AppColors` and the application `ThemeData`. Do not hardcode color literals
in screens or feature widgets. Prefer semantic names such as
`AppColors.textPrimary`, `AppColors.textMuted`, and `AppColors.backgroundLight`
so visual changes remain centralized.

Use the theme text styles and apply only the semantic differences the component
owns, such as weight or foreground color.

## Scrolling and refresh

Prefer slivers and `CustomScrollView` through `AppScaffold.scrollable`.
`SingleChildScrollView` should not be the default screen structure. Provide
`onRefresh` to the scaffold when the screen supports pull-to-refresh.

The scrollable scaffold automatically adds bottom clearance for the floating
navigation bar. Do not add a second screen-level bottom spacer unless the
content has an additional documented requirement.

## Shared surfaces

- Use `BaseSection` for titled content groups.
- Use `BaseCard` for repeatable card surfaces and tap handling.
- Keep feature-specific presentation in the owning feature directory.
- Promote a feature widget to `common_widgets/` only after its shared contract
  is clear from real reuse.

## Review checklist

- The screen uses the appropriate `AppScaffold` constructor.
- Scrollable content is expressed as slivers.
- Loading, empty, error, and success states are represented.
- Spacing and colors use semantic application constants.
- Floating-navigation overlap and safe areas are handled exactly once.
- Shared components contain no repository or business logic.
- User-facing text comes from slang localization sources.
