# Flutter UI component design

Status: Current implementation guide. The applicable `AGENTS.md` remains the
authoritative source for agent rules.

PepperCheck composes screens from a small set of shared Flutter widgets. Shared
widgets own visual structure and interaction mechanics; feature widgets own
feature presentation; application and data behavior stays outside reusable UI
components.

## Component hierarchy

```text
lib/
├── common_widgets/
│   ├── app_scaffold.dart
│   ├── base_section.dart
│   ├── base_card.dart
│   └── ...
├── app/theme/
│   ├── app_colors.dart
│   ├── app_sizes.dart
│   └── app_theme.dart
└── features/<feature>/ui or presentation/
    └── widgets/
```

Use `common_widgets/` only for components shared across features. Keep a widget
inside its owning feature until a second real consumer establishes a shared
contract.

## AppScaffold

`AppScaffold` supplies the shared application navigation, transparent page
surface, title treatment, and bottom-navigation clearance.

Use `AppScaffold.scrollable` for standard screens. It accepts slivers, applies
the standard screen padding, adds clearance for the floating navigation bar,
and optionally wraps the scroll view in a refresh indicator.

```dart
AppScaffold.scrollable(
  title: 'Tasks',
  onRefresh: viewModel.refresh,
  slivers: [
    SliverList.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) => TaskCard(task: tasks[index]),
    ),
  ],
)
```

Use `AppScaffold.fixed` only for a deliberately fixed or custom-scrolling body.
It does not add page padding or bottom-navigation clearance.

## BaseSection

`BaseSection` groups a titled area on the standard light surface. It owns title
typography, padding, radius, and the title-to-body gap. The optional `trailing`
widget is for a compact title-row action or indicator.

```dart
BaseSection(
  title: 'Availability',
  trailing: IconButton(
    onPressed: onAdd,
    icon: const Icon(Icons.add),
  ),
  child: AvailabilityList(items: items),
)
```

Do not reproduce the section container with an ad hoc `Container` or `Card`.
If the shared contract lacks a needed capability, extend `BaseSection` when the
capability is broadly applicable; otherwise compose the feature-specific detail
inside its `child`.

## BaseCard

`BaseCard` is the reusable card shell used inside sections and other compact
surfaces. It provides the standard background, radius, padding, optional border,
and optional tap handling while leaving content layout to the caller.

Prefer composition over adding feature-specific properties to `BaseCard`.
Feature widgets such as task cards and profile rows should assemble their own
content inside the shared shell.

## State and behavior

Shared visual components receive values and callbacks. They do not read feature
repositories, create network clients, or perform business decisions. Feature
screens or view models own loading, empty, error, and success states and pass the
renderable state into widgets.

For the current spacing, color, scaffold, and scrolling conventions, see
[Flutter UI guidelines](ui-guidelines.md).
