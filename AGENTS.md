# AGENTS.md

## Rule Authority

- The shared `~/.agents/AGENTS.md` is the source of truth for common agent
  rules. This repository file adds only PepperCheck-specific guidance.
- Do not use `developer-docs/` or the external developer-documentation
  repository as a source of contribution, issue, task, workflow, or engineering
  rules.
- Treat `developer-docs/` as legacy content pending documentation cleanup.
  Inspect it only when a task explicitly requires migrating or auditing that
  content.
- If another document conflicts with the shared or repository `AGENTS.md`,
  follow the applicable `AGENTS.md` guidance.

## Tools

### Github Operations

- Use `gh` command

## Go/VPS Refactoring Plans

Implementation plans for the Supabase-to-Go/VPS refactoring program are a
temporary exception to the general rule that working plans are not committed.

- Commit existing program plans under `docs/development/go-vps-plans/` so later phases
  can reuse their implementation details, constraints, and verification steps.
- GitHub Issues remain the source of truth for work status, priority,
  dependencies, and acceptance. Plan checkboxes are implementation guidance,
  not a second work tracker.
- Mark a completed phase plan as `Implemented`, but retain it until the overall
  refactoring program is complete. Remove the temporary program plans in the
  final cleanup after durable decisions have been preserved in design documents.
- Revalidate a plan against the current code, approved design, dependency
  versions, and official third-party documentation before executing it.
- Starting with Phase 4b, creating a separate implementation plan is optional.
  An approved design document plus sufficiently scoped GitHub Issues and
  acceptance criteria are enough when they provide clear implementation
  guidance. Create a plan only when sequencing, migration risk, cross-component
  coordination, or detailed verification makes one useful.
- The existing Phase 4b plan remains a retained program plan; this policy does
  not require equivalent plans for later phases.

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
