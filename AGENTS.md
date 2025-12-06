# AGENTS.md

## Contribution Rules

Before producing any output related to issues, tasks, or project management:

1. Use the web search/browsing tool to open and read all pages listed below.
2. Follow the rules described in these pages.

### Required pages

- https://raw.githubusercontent.com/cloveclovedev/cloveclove-developer-docs/main/modules/ROOT/pages/contribution/issue.adoc
  (Access the raw content, not the rendered HTML.)

If the web tool is unavailable or the pages cannot be loaded:

- **Leave all contribution-related actions to the user.**
- Provide assistance only when explicitly instructed by the user.

## Tools

### Github Operations

- Use `gh` command

## PepperCheck Flutter Best Practices

### Screen Implementation

#### Scaffold Architecture

We use a custom `AppScaffold` to ensure consistent UI, standard navigation, and correct padding across all main application screens.
We provide two distinct constructors to enforcing robust layouts:

1. **`AppScaffold.scrollable`** (Recommended)
   - **Use when**: Building standard internal screens with lists or scrollable content.
   - **Features**:
     - Accepts `slivers` (standard Flutter slivers).
     - **Automatic Padding**: Applies standard screen padding (`horizontal: 16, vertical: 8`) automatically.
     - **Bottom Padding**: Automatically adds padding for the floating navigation bar.
     - **Refresh**: Supports pull-to-refresh via standard `onRefresh` parameter.
   - **Example**:
   ```dart
   AppScaffold.scrollable(
     title: 'My Tasks',
     // Standard padding is applied automatically around these slivers
     slivers: [
       SliverList(...),
       // Or for non-list content:
       SliverToBoxAdapter(child: MyFormWidget()),
     ],
   )
   ```

2. **`AppScaffold.fixed`**
   - **Use when**: Building screens with **zero padding** (e.g. Map, Full-screen image) or manual layout control is required.
   - **Features**:
     - Accepts a standard `Widget body`.
     - **No Automatic Padding**: You are responsible for all padding, including bottom navigation overlap.
     - Uses `extendBody: true` by default (content goes behind navigation bar).
   - **Example**:
   ```dart
   AppScaffold.fixed(
     title: 'Profile',
     body: Center(child: Text('Fixed Content')),
   )
   ```

#### Layout & Padding

- **Horizontal Padding**: Standard padding (16.0) is handled by `AppScaffold.scrollable`.
- **Vertical Spacing**: Use `AppSizes.sectionGap` (8.0).
- **Bottom Navigation**: The Navigation Bar is floating. `AppScaffold.scrollable` handles the offset automatically.

#### Scrolling

We prefer **Slivers** (`AppScaffold.scrollable` + `CustomScrollView`) over `SingleChildScrollView` for performance and flexibility.
For form-like content that isn't a list, wrap it in a `SliverToBoxAdapter`.

### Theme & Constants

**Do NOT hardcode colors or sizes.**
Always use the semantic constants defined in the application theme to ensure consistency and maintainability.

- **Colors**: Use `AppColors` (e.g., `AppColors.textPrimary`, `AppColors.textMuted`, `AppColors.backgroundDark`).
- **Sizes**: Use `AppSizes` (e.g., `AppSizes.baseSectionHorizontalPadding`, `AppSizes.taskCardGap`).
  - Creating new constants in `AppSizes` or `AppColors` is preferred over hardcoding, even for one-off values that might be reused later.
