# Harness engineering report

Living record for the agent harness used across PepperCheck and personal
projects. It distinguishes durable product policy from external technical
guidance, records why a skill is selected or rejected, and makes external
updates reviewable.

Last reviewed: 2026-07-27.

## Scope and invariants

- This report does not modify or replace any `.claude` configuration. Claude
  Code remains independently configured.
- The Supabase-to-Go/VPS migration removes Supabase from the target runtime;
  Supabase workflows are outside this report's adoption scope.
- `AGENTS.md` is the source of truth for product decisions and hard constraints.
  A third-party skill can supply procedures and technical context, but cannot
  override it.
- External skills are dependencies, not unreviewed prompts. Their source,
  license, revision, scope, and changes must be recorded before adoption.
- Do not use a skill's bundled scripts, MCP configuration, or tool permissions
  until they have been separately reviewed.

The target stack is Flutter/Dart on Android and iOS; a Go API, worker, and
server-rendered web surface; PostgreSQL managed with Atlas; Firebase Auth/FCM;
Cloudflare R2; Stripe/RevenueCat; and Caddy plus Docker Compose on a VPS. See
[the refactor strategy](superpowers/specs/2026-07-22-supabase-to-go-vps-refactor-design.md).

## Harness model

| Layer | Owner | Purpose | Examples |
| --- | --- | --- | --- |
| Global guidance | `dotfiles/agents/AGENTS.md` | Small, always-applicable personal standards | language, secret handling, branch safety, default stack |
| Global skills | `dotfiles/agents/skills/` | Task-specific knowledge reused across products | Flutter/Dart, Atlas, selected Android skills |
| Repository guidance | Repository `AGENTS.md` | Product architecture and non-negotiable conventions | Riverpod 3, `AppScaffold`, `slang`, Dio, Go feature layout |
| Repository skills | `.agents/skills/` | Workflows meaningful only for the repository | release operation, product-specific test harness |
| Vendor source | `dotfiles/agents/vendor/` | Pinned upstream checkout or reviewed snapshot | `flutter/agent-plugins`, `dart-lang/skills` |

Codex loads only a skill's metadata initially and reads the full `SKILL.md`
when the task matches. This permits a curated collection without adding every
workflow to every prompt. See the [Codex skills documentation](https://learn.chatgpt.com/docs/build-skills.md).

A link to an uninstalled skill is **not** an operational mechanism. It has no
automatic trigger and must never be presented to the agent as "look here if
useful". A workflow is either an installed skill with an explicit trigger
description, or it is not part of the agent harness.

## Evaluation rubric

Before adding a skill, assess all of the following.

1. **Authority and maintenance:** Is it maintained by the technology vendor,
   OpenAI, or a third party? Does it state a license and a recent revision?
2. **Task fit:** Does it cover a recurrent task in the target stack rather than
   a technology merely present in the repository?
3. **Policy compatibility:** Does it conflict with `AGENTS.md`, installed
   dependencies, architecture, localization, networking, or security policy?
4. **Execution surface:** Does it carry scripts, MCP configuration, hooks, or
   tool-permission requests? Those are separately reviewed and never enabled by
   installing instructional content alone.
5. **Update cost:** Can a maintainer review an upstream revision and roll back
   to a known-good revision?

Use this outcome vocabulary. Every status has a defined installation and
activation behavior.

| Status | Installation and activation behavior | Typical use |
| --- | --- | --- |
| **Adopt** | Install the reviewed upstream skill unchanged, pin its source, and expose it through `~/.agents/skills` or the repository. Codex may select it from its description; a user may also invoke it explicitly. | Vendor guidance already matches product policy. |
| **Adapt** | Create and expose an owned skill whose `SKILL.md` contains the compatible workflow and an explicit description. Pin the upstream material only as a review input; it is not activated. | Guidance is valuable but needs product-specific architecture, security, or tool restrictions. |
| **Reference only** | Do not install or expose the source. It has no Codex trigger. Keep a source-registry record solely for a human author when evaluating a future owned skill. | A useful article or bundle that is too broad or policy-incompatible to activate. |
| **Defer** | Do not install or expose it yet. Record the prerequisite and the review needed to decide later. | A target technology is not in active use or its test/release workflow is not chosen. |
| **Reject** | Do not install or expose it. Record the incompatibility; reconsider only after a material stack or upstream change. | It conflicts with an existing product decision. |

For an installed skill, the model performs the normal implicit selection from
the skill description; users can invoke it explicitly. Critical product rules
must instead remain in `AGENTS.md` (and be repeated in an owned skill where
useful), because a selection description is not a deterministic policy engine.

## Assessed sources

### Flutter and Dart official skills

Sources:

- [Flutter Agent Skills documentation](https://docs.flutter.dev/ai/agent-skills)
- [flutter/agent-plugins](https://github.com/flutter/agent-plugins)
- [dart-lang/skills](https://github.com/dart-lang/skills)

Both repositories are maintained by their respective framework teams. Flutter
documents the universal Agent Skills installation route and also offers a Codex
plugin. The plugin contains more than skills: its `.mcp.json` starts the Dart
MCP server with `dart mcp-server`. Prefer reviewed universal skills first;
consider the plugin only after separately validating the MCP server, its
permissions, and its value for this workflow.

#### Flutter skill decisions

| Skill | What was reviewed | Decision | Rationale |
| --- | --- | --- | --- |
| `flutter-add-widget-test` | `WidgetTester`, finders, interaction, and `flutter test` workflow | Adopt | Fits the Flutter test stack and has no dependency conflict. Repository test fixtures and Riverpod provider overrides remain authoritative. |
| `flutter-fix-layout-issues` | Layout-error troubleshooting workflow | Adopt | Useful for bounded Flutter rendering failures. PepperCheck's `AppScaffold` and spacing rules override generic layout changes. |
| `flutter-build-responsive-layout` | `LayoutBuilder`, `MediaQuery`, and flexible layout workflow | Adopt | Useful when a screen must support tablets or web. Do not introduce responsive redesigns unless the task requests them. |
| `flutter-setup-declarative-routing` | GoRouter, deep links, platform association files, nested navigation | Adapt | The project already uses GoRouter. Use it for new routes or deep links only; retain the project's router and authentication conventions. |
| `flutter-add-widget-preview` | `previews.dart` workflow | Defer | No widget-preview system has been selected for PepperCheck. |
| `flutter-add-integration-test` | `integration_test`, Dart/Flutter MCP, and legacy `flutter_driver` paths | Defer | The workflow mixes modern `integration_test` with Flutter Driver setup and a host driver. Select a project test runner before enabling it. Never add `enableFlutterDriverExtension()` automatically. |
| `flutter-apply-architecture-best-practices` | MVVM via `ChangeNotifier`, service/repository layers, `get_it` or provider | Reject | Conflicts with the established Riverpod 3, feature-based architecture and the rule against unnecessary interfaces/layers. |
| `flutter-implement-json-serialization` | Manual `fromJson`/`toJson`, `dart:convert`, and `http` | Reject | The project uses Freezed and `json_serializable` for DTOs, not manual models. |
| `flutter-setup-localization` | ARB, `gen-l10n`, and `l10n.yaml` | Reject | PepperCheck uses slang; the existing localization source and generation process must remain unchanged. |
| `flutter-use-http-package` | Direct `http` calls and `FutureBuilder`-centred presentation | Reject | The app uses Dio in `core/network` and Riverpod state management. |

#### Dart skill decisions

| Skill | What was reviewed | Decision | Rationale |
| --- | --- | --- | --- |
| `dart-add-unit-test` | Test structure, `group`, `setUp`, and Flutter vs Dart runners | Adopt | Compatible with Flutter tests and the existing test layout. |
| `dart-generate-test-mocks` | Mockito, `@GenerateNiceMocks`, `build_runner`, async stubs | Adopt | Mockito and `build_runner` are existing development dependencies. Use provider overrides where they give a simpler Flutter test. |
| `dart-run-static-analysis` | Analyze, dry-run fixes, formatting, analyzer configuration | Adapt | Use the project's Flutter-aware validation command and review `dart fix --dry-run` before any application. Do not make broad automatic fixes. |
| `dart-use-pattern-matching` | Dart 3 patterns and exhaustiveness | Adopt | Applicable to the supported Dart SDK; use where it improves clarity, not as a rewrite mandate. |
| `dart-resolve-package-conflicts` | `pub outdated`, constraints, lockfile handling | Adapt | The diagnostic workflow is useful. Do not edit `pubspec.lock` by hand without a concrete resolver failure and review. |
| CLI, FFI, `ffigen`, and `checks` migration skills | Workflows for unused application surfaces | Defer | They do not serve the current Flutter product. |

**Scope:** the adopted Flutter/Dart skills are global developer skills because
they apply to multiple Flutter products. PepperCheck-specific requirements stay
in its `AGENTS.md`.

### Android official skills

Source: [android/skills](https://github.com/android/skills), maintained by
Google and licensed under Apache-2.0. It is intentionally focused on Android
workflows where agents underperform, not general Compose guidance.

| Skill or family | Decision | Rationale |
| --- | --- | --- |
| `android-cli` | Defer pending inspection | Potentially useful for native Android diagnosis and project tooling. Evaluate its executable requirements before adoption. |
| Google Play skills | Defer pending inspection | Potentially valuable for Play Console/release tasks, but must be assessed with the release checklist and external-write approval policy. |
| Android intent security | Defer | Revisit when implementing or changing deep links, intent filters, or share targets. |
| `testing-setup` | Reject for this repository | Its workflow assumes a native Kotlin architecture and can introduce Hilt, Espresso, Compose testing, or Robolectric. Flutter owns application testing here. |
| `edge-to-edge` | Reject for this repository | Its prerequisite is a Jetpack Compose app. It is not applicable to Flutter-rendered screens. |
| Compose, CameraX, Wear, XR, and AGP migration skills | Defer | No target component currently uses them. |

**Scope:** selected Android skills belong in the global collection, but are used
only while editing native Android files. They must not influence Dart UI design.

### Go skills from `samber/cc-skills-golang`

Source: [samber/cc-skills-golang](https://github.com/samber/cc-skills-golang),
MIT licensed and third-party. The project publishes a large, cross-referencing
set of general and library-specific Go skills and recommends installing its
general-purpose set together.

Representative reviewed content is valuable but not policy-compatible without
adaptation:

- `golang-code-style` has useful clarity, early-return, standard-library, and
  `slog` guidance, but also mandates choices such as non-nil slices and permits
  `samber/lo`.
- `golang-project-layout` is pragmatic about avoiding over-structure, but asks
  users to choose architecture and DI, and mandates files and tools that are not
  PepperCheck policy.
- `golang-dependency-injection` correctly prefers manual construction for small
  services, but makes interface-based fakes and DI libraries central options.
  PepperCheck instead adds interfaces only for a real alternative implementation
  or test need and prefers integration tests against a real database.

**Decision: reference only.** Do not install this collection as an activating
global skill bundle. It is a useful source for an owned `go-service` skill, but
the owned skill must express the existing Go/Flutter correspondence, standard
library-first policy, explicit composition root, real-Postgres integration
tests, and deliberately rare interfaces. Review the upstream source again when
the owned skill is authored; do not copy its `allowed-tools`, model-specific
orchestration instructions, or framework-specific skills.

### Atlas

There is an existing optional Atlas skill in the dotfiles repository. Its
versioned migration workflow, `atlas.hcl`-first inspection, validation, lint,
testing, and dry-run sequencing fit the target PostgreSQL/Atlas stack.

**Decision: adapt into an owned global `atlas` skill.** Remove the Neon-specific
reference and its example that reads `.env`; it conflicts with the global
secret-file policy and does not match the self-hosted VPS target. Before each
Atlas implementation or skill revision, verify commands and edition-dependent
features against current [Atlas documentation](https://atlasgo.io/docs).

### Firebase official skills

Source: [Firebase agent skills](https://firebase.google.com/docs/ai-assistance/agent-skills).
Firebase officially supports Codex and distributes the skills as a Codex
plugin. The bundle can include instructions, automation scripts, and Firebase
MCP guidance, so installation must not be treated as a content-only change.

The target architecture uses Firebase Authentication and FCM, not Firestore,
Data Connect, Firebase Hosting, or Firebase App Hosting. The initial candidate
is therefore only `firebase-auth-basics`; `firebase-crashlytics` is a future
candidate if Crashlytics is selected. The database, hosting, AI Logic, and
Firestore security-rule skills are out of scope for this product.

**Decision: defer installation pending a content and execution-surface review
of the two candidates.** If adopted, use the vendor-managed Codex plugin for
that narrow Firebase workflow, record the installed plugin revision and its
approved commands in the dotfiles source registry, and update it through a
reviewed marketplace upgrade rather than an unattended refresh. Do not install
the Firebase MCP server merely because the skill documentation recommends it;
MCP access to Firebase projects is a separate authority decision.

### Riverpod, slang, and Dio

The repository already pins Riverpod 3.0.3 (including generator and lint),
slang 4.11.0, and Dio 5.9.0. These are compatible, deliberate product choices;
the Flutter official skill catalog's examples using `ChangeNotifier`,
`gen-l10n`, or `http` are generic recipes, not recommendations to replace
them.

No vendor-maintained Agent Skill for Riverpod, slang, or Dio was identified in
the Flutter/Dart official catalogs or the respective upstream repositories
during this review. For a one-off API question, inspect the pinned package
version and its official documentation first; documentation lookup is more
accurate and lower-maintenance than inventing a broad skill.

**Decision: defer an owned `riverpod-3` skill until a repeated workflow is
identified.** A useful narrow version would trigger only when adding or
changing a provider, notifier, provider scope, or generated provider. It would
require checking the pinned version and current official Riverpod 3 guidance,
then apply PepperCheck's feature and test conventions. It must not duplicate
the external manual or force a documentation lookup for unrelated Flutter UI
work. Apply the same threshold to future slang or Dio skills.

### Existing provider skills

The current Codex environment already exposes PostgreSQL best-practices and
Stripe skills. They remain relevant after Supabase removal because PostgreSQL
and Stripe Connect remain in the target architecture. Do not create a parallel
Supabase workflow skill. Verify their installation and versioning during the
dotfiles implementation phase before deciding whether they need an explicit
managed source entry.

### Pending research

| Target technology | Current decision | Required follow-up |
| --- | --- | --- |
| Firebase Auth and FCM | Vendor source found; installation deferred | Review `firebase-auth-basics` and, if Crashlytics is adopted, `firebase-crashlytics`; separately decide whether any Firebase MCP authority is appropriate. |
| iOS / Sign in with Apple | No source selected | Locate Apple-maintained Skills; otherwise define only the repeatable project-safe workflow. |
| Cloudflare R2 | No source selected | Evaluate an R2-specific vendor source. Do not adopt a Worker/Pages deployment skill for an R2-only task. |
| Go `html/template`, htmx, and Tailwind | No source selected | Base product guidance is sufficient for ordinary pages. Add a narrow owned skill only after a repeated workflow such as accessibility review, design-token application, or template/component conventions emerges. |
| Docker Compose, Caddy, backups, and VPS operations | No source selected | Evaluate during Phase 7 against the operator-private release checklist. |

## External source lifecycle

Use a controlled vendor layout in dotfiles for copied or symlinked Agent Skills
rather than a one-off install into `~/.codex/skills`:

```text
dotfiles/agents/
├── AGENTS.md
├── skills/                         # direct, Codex-discoverable skill folders
│   ├── atlas/                      # owned
│   ├── flutter-add-widget-test -> ../vendor/flutter-agent-plugins/skills/...
│   └── dart-add-unit-test -> ../vendor/dart-skills/skills/...
└── vendor/
    ├── flutter-agent-plugins/      # pinned upstream source
    └── dart-skills/                # pinned upstream source
```

`setup.sh` should expose `dotfiles/agents/skills` at `~/.agents/skills` using
a safe symlink or per-skill links. Codex supports user-level skills from that
directory and follows symlinked skill folders. Do not add a copied skill to
each product repository when a global skill is intended.

Maintain an English, tracked source registry in dotfiles. For every external
source it must record:

- source URL, license, selected skill folders, and immutable commit SHA;
- date and reviewer of the last content/security/compatibility review;
- whether bundled scripts, MCP configuration, hooks, or `allowed-tools` are
  approved, rejected, or not applicable;
- compatibility notes and the product policy that overrides it.

### Update procedure

1. Fetch the upstream source without changing the active symlink or pinned
   revision.
2. Diff the currently pinned revision against the candidate revision, including
   `SKILL.md`, scripts, MCP files, manifests, and licenses.
3. Reapply the evaluation rubric. Check current framework/library versions and
   run a representative task in a disposable worktree if the change is
   material.
4. Update the pin and source registry in one reviewed dotfiles change.
5. Run the dotfiles setup verification, open a fresh Codex session, and confirm
   the expected skills are discovered.
6. Roll back by returning the source registry and vendor pin to the previous
   commit.

Never use a broad `skills update` command as an unattended updater. The
upstream command is useful for discovery, but controlled updates preserve a
reproducible harness and make new scripts or instructions visible in review.
For a Codex marketplace plugin such as Firebase, review the candidate plugin
version and marketplace upgrade in the same way; record the installed plugin
revision and approved execution surface in the source registry.

## Rollout sequence

1. Create the dotfiles skill source registry and the safe `~/.agents/skills`
   linking mechanism. No PepperCheck source or `.claude` file changes are
   required.
2. Vendor and pin the adopted Flutter/Dart official skill folders. Validate
   discovery in a fresh Codex session from a Flutter repository.
3. Author and validate the owned global `atlas` skill after removing
   secret-reading and Neon-specific guidance.
4. Inspect the deferred Android skills before adding any of them.
5. Author an owned Go service skill from PepperCheck policy and reviewed
   upstream references; do not import the third-party Go collection wholesale.
6. Revisit the pending research table as each refactor phase reaches the
   relevant technology.
