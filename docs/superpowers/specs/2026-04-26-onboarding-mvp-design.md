# Onboarding MVP Design

## Date

2026-04-26

## Problem

The MVP v1.0.0 closed test is approaching. New users currently see only a minimal LoginScreen (logo + "Continue with Google") with no explanation of what PepperCheck does or how it works. After signing in, they encounter UI elements (受付可能時間, ブロック日, payment summary point cards) that may not be self-explanatory.

Identified pain points for new users:

- Concept understanding: task creation flow with referees, point/subscription system, referee-side experience
- UI element specifics: profile screen settings, payments summary point breakdown

The team also has a strong constraint: **"if not implemented now, likely never implemented in production either"**, which removes "deferred polish" as an option.

The team values the LoginScreen's current minimalism and wants to preserve it.

## Goals

- Communicate the app concept to first-time users without breaking the LoginScreen's minimal aesthetic
- Provide contextual help for specific UI elements that benefit from explanation
- Keep the implementation pull-based (no forced flow, no first-launch persistence flag)
- Establish reusable base widgets for BottomSheet and Dialog patterns since these usages will likely grow

## Non-Goals (Out of Scope for v1.0)

- Pre-login intro carousel (3-4 swipe pages)
- Coach mark / spotlight tutorial overlay
- Auto-show on first launch (would require a "seen" persistence flag)
- `?` icon coverage on screens beyond profile and payments (home, task screens etc. deferred)
- English translation of new content (handled in existing slang workflow, follows current cadence)
- Carousel UI for the explanation BottomSheet (data structure is prepared for future migration; v1.0 ships single-pass layout)
- Refactoring existing BottomSheet/Dialog implementations to use the new base widgets (handled in follow-up PRs)
- `?` icon on the payments "出金情報" / payout setup section (already has inline explanations)
- Subscription section `?` icons (judged self-explanatory)

## Design

### Architecture overview

Two surfaces share one app concept explanation:

- **App-level concept explanation** → `BaseBottomSheet`, opened from LoginScreen and Profile screen
- **Element-level help** → `BaseDialog`, opened from `?` icons on specific cards/sections

Pull-based throughout: user taps to open. No auto-show, no forced flow, no "seen" flag persisted.

### 1. Base widgets (new)

Both base widgets codify the visual shell currently used by `plan_selection_bottom_sheet.dart` (BottomSheet reference) and `delete_account_confirmation_dialog.dart` (Dialog reference). Future BottomSheet/Dialog usages share a consistent visual shell.

Existing implementations of these patterns are NOT refactored in this PR (handled separately).

#### 1a. `BaseBottomSheet`

**Location:** `common_widgets/base_bottom_sheet.dart`

**API (sketch):**

```dart
Future<T?> showBaseBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext) contentBuilder,
});
```

**Shell responsibilities (encapsulated, callers do not handle these):**

- `showModalBottomSheet<T>` with `isScrollControlled: true`
- Drag handle: 32×4, `Colors.grey[400]`, radius 2
- Title: `titleSmall + bold + AppColors.textPrimary`
- Outer padding: `AppSizes.screenHorizontalPadding`
- Bottom inset handling: `MediaQuery.viewInsets.bottom + viewPadding.bottom` — handles both keyboard and home indicator without callers touching MediaQuery
- Wraps content in `SingleChildScrollView` (overflow safety net only — content should be designed to fit without scrolling on common devices)

The `useSafeArea: true` shorthand is intentionally not used here; the explicit MediaQuery sum handles both keyboard and home indicator in one place, matching the existing reference implementation.

#### 1b. `BaseDialog`

**Location:** `common_widgets/base_dialog.dart`

**API (sketch):**

```dart
class BaseDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
}
```

**Shell responsibilities:**

- `AlertDialog` with `backgroundColor: AppColors.backgroundWhite`, `surfaceTintColor: Colors.transparent`
- Shape: `RoundedRectangleBorder(radius: 16, side: BorderSide(color: AppColors.border))`
- Title: `titleMedium + bold + AppColors.textPrimary`
- Content: wrapped in `SingleChildScrollView`
- Actions: rendered via the standard `actions` slot

#### 1c. `BaseSection` extension (existing widget, additive change)

**Location:** `common_widgets/base_section.dart` (existing)

Add an optional `trailing` parameter:

```dart
class BaseSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;  // NEW
}
```

When `trailing` is non-null, the title row is rendered as a `Row` with the title on the left and `trailing` aligned to the right, sharing the existing horizontal padding. When `trailing` is null, behavior is unchanged.

The trailing widget must not increase the title row's height — it's expected to fit within the existing row bounds (see HelpIconButton sizing constraint below). The title's vertical baseline and the section's overall height stay unchanged.

This lets `HelpIconButton` slot in cleanly without duplicating title-row layout in every callsite. For `BaseCard`-based cards (payment summary), callers compose the `?` icon manually within the card content (no API change to `BaseCard`).

### 2. `HelpIconButton` (new)

**Location:** `common_widgets/help_icon_button.dart`

**API:**

```dart
class HelpIconButton extends StatelessWidget {
  final String title;  // dialog title
  final String body;   // dialog body
}
```

Renders a small `Icons.help_outline` (or visually equivalent) icon. On tap, calls `showDialog` with a `BaseDialog` containing the provided title + body and a single "閉じる" action.

#### Sizing constraint (must-have)

The `?` icon's introduction must NOT cause the host section/card to grow in any dimension. Specifically:

- **Icon glyph size**: ~16px (small) — at most as tall as the title text it sits next to. Never larger than the existing title's cap height + a small margin.
- **Tap target**: a minimum touch area is provided via the padded hit area, but the **entire icon + hit area must fit within the existing title row's vertical bounds**. The host section/card's overall height stays unchanged compared to today.
- **Do NOT use** Flutter's `IconButton` directly — its default 48×48 padding will inflate the row. Use a custom `GestureDetector` (or a tightly constrained `InkWell` with `BoxConstraints(minWidth: 0, minHeight: 0)`) so the visual size and the hit area are decoupled cleanly.
- **Horizontal placement**: trailing-aligned in the title row. If horizontal space is tight, the tap area extends to the right edge of the row but does not push other content.

This is a hard constraint: existing section/card dimensions are part of the design and must be preserved.

#### Help content design principle

When a user taps a `?` icon, they want to understand both **what** the thing is and **why it exists**. Help body copy should answer both when the "why" is non-obvious. Pure dictionary definitions ("X is the count of Y") leave users with the question still unanswered. The "why" answer becomes meaningful when the existence of the concept is non-obvious (e.g., "レフリー義務" — users will wonder why this is imposed at all).

This principle is reflected in the `B5 レフリー義務` copy below.

### 3. `AppExplanationBottomSheet` (new)

**Location:** `features/about/presentation/app_explanation_bottom_sheet.dart`

The shared concept-explanation BottomSheet, opened from both LoginScreen and Profile.

**Open API:**

```dart
Future<void> showAppExplanationBottomSheet(BuildContext context);
```

**Sheet title:** `PepperCheckとは`

**Internal structure (carousel-reservation):**

```dart
class _ExplanationSection {
  final IconData icon;
  final String title;
  final String body;
}

class _AppExplanationBody extends StatelessWidget {
  static final List<_ExplanationSection> _sections = [
    // 4 sections, see "Content" below
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final section in _sections)
          _ExplanationSectionTile(section: section),
        const SizedBox(height: AppSizes.spacingMedium),
        _LearnMoreLink(),  // peppercheck.dev
      ],
    );
  }
}
```

**Carousel migration path:** Future change replaces the outer `Column(...)` with `PageView(...)` and adds a page indicator + Skip button. Section data and `_ExplanationSectionTile` widget stay unchanged.

#### Section tile layout (compact horizontal)

To fit all 4 sections on screen without scrolling on common phones, each `_ExplanationSectionTile` uses a compact horizontal layout: icon on the left, title and body stacked vertically on the right.

```
[icon] [Title — short, 1 line          ]
       [Body — 2-3 sentences, wraps     ]
       [as needed                       ]
```

This is significantly more vertically compact than a centered icon→title→body stack. Spacing between sections uses `AppSizes.spacingStandard` or similar. On small devices where content still overflows, the underlying `SingleChildScrollView` provides graceful fallback.

#### Footer

Tappable text "詳しくは peppercheck.dev で" → opens `https://peppercheck.dev` via `url_launcher` (`LaunchMode.externalApplication`).

### 4. LoginScreen change

**Location:** `features/authentication/presentation/login_screen.dart` (existing)

Add a small text link below the Google sign-in button:

```
[ロゴ]
PepperCheck
[Continue with Google]
PepperCheckとは？      ← NEW (small, low-emphasis text link)
```

Tapping calls `showAppExplanationBottomSheet`.

Style:

- `textTheme.bodySmall` or comparable
- `AppColors.textSecondary`
- Wrapped in `GestureDetector` (`HitTestBehavior.opaque`) with vertical padding of `AppSizes.spacingTiny` for tap target

The existing `Spacer` + logo + title + CTA layout is otherwise unchanged. The new link sits in the existing trailing `Spacer` slot — to be tuned at implementation time so the visual rhythm of the screen still matches today.

### 5. Profile screen addition

**Location:** `features/profile/presentation/profile_screen.dart`

Add a menu entry "PepperCheckについて" that calls `showAppExplanationBottomSheet`. Placement: alongside other meta entries (e.g., near "Settings" / account actions). Exact placement decided at implementation time based on existing profile layout.

### 6. `?` icon placements (v1.0 scope)

#### 6a. Profile screen — matching feature

Two `?` icons via the new `BaseSection.trailing` slot:

| Section | `?` content |
|---------|------------|
| 受付可能時間 (`RefereeAvailabilitySection`) | B1 (see Content below) |
| ブロック日 (`RefereeBlockedDatesSection`) | B2 |

#### 6b. Payments screen — payment summary point cards

Each summary point card receives a `?` icon. Payment cards are built on `BaseCard` (not `BaseSection`), so the icon is composed manually inside the card content — typically as a trailing element of the card's title/label row. Exact composition is decided per-card at implementation time within the existing card layout. Cards covered:

| Card | `?` content |
|------|------------|
| 利用可能ポイント | B3a |
| ロック中ポイント | B3b |
| トライアルポイント | B4 |
| 未履行のレフリー義務 | B5 |
| 報酬残高 | B6 |
| 累計受取額 | B7 |

Subscription section, payout setup section, and 出金可能額 are explicitly excluded (see Non-Goals).

## Content

Final Japanese copy. Implementation places these into slang under the `app_explanation` and `help` namespaces (see Slang Structure below).

### A. AppExplanationBottomSheet

**Sheet title:** `PepperCheckとは`

| # | Icon | Title | Body |
|---|------|-------|------|
| 1 | `Icons.flag_outlined` | 社会的責任感を、目標達成の力に | 自分との約束は破ってしまいがち。PepperCheckは、達成したいタスクを第三者のレフリーに確認してもらうことで、その「社会的責任感」を目標達成のエネルギーに変えるアプリです。 |
| 2 | `Icons.task_alt` | タスク完了までのフロー | 達成基準と締切を決めてタスクを作成します。システムが自動でレフリーをマッチングし、レフリーは提出されたエビデンスをもとに、タスクが達成されたかどうかを判定します。 |
| 3 | `Icons.workspace_premium` | ポイントでタスクを作成 | タスク作成にはポイントが必要で、サブスクリプションに加入すると毎月ポイントが付与されます。初めての方はトライアルポイントで無料で試せます。 |
| 4 | `Icons.gavel` | レフリーをして、報酬を獲得 | あなた自身も他のユーザーのレフリーを担当できます。受付可能時間を設定するとマッチング対象になり、判定を完了するごとに報酬が貯まっていきます。貯まった報酬は決済プラットフォームStripeを通じて指定した銀行口座に出金されます。 |

**Footer text:** `詳しくは peppercheck.dev で`
**Footer URL:** `https://peppercheck.dev`

### B. `?` icon Help Dialogs

| # | Mounted on | Title | Body |
|---|-----------|-------|------|
| B1 | 受付可能時間 (Profile) | 受付可能時間とは？ | レフリーとしてタスクを担当できる曜日・時間帯です。この時間が締切のタスクがマッチング対象になります。 |
| B2 | ブロック日 (Profile) | ブロック日とは？ | レフリー業務を一時的に停止したい日を指定できます。ブロック日と重なるタスクは、受付可能時間内であってもマッチング対象から外れます。 |
| B3a | 利用可能ポイント (Payments) | 利用可能ポイントとは？ | タスク作成に使えるポイント残高です。サブスクリプションに加入すると毎月付与されます。 |
| B3b | ロック中ポイント (Payments) | ロック中ポイントとは？ | 進行中のタスクで仮押さえされているポイントです。タスクの結果に応じて、消費または返却されます。 |
| B4 | トライアルポイント (Payments) | トライアルポイントとは？ | 初めての方が無料でPepperCheckを試せるポイントです。タスク作成に使うと、他のユーザーのレフリーを無料で1回務める「レフリー義務」が発生します。 |
| B5 | 未履行のレフリー義務 (Payments) | レフリー義務とは？ | トライアルポイントでタスクを作成した代わりに、他のユーザーのレフリーを無料で担当する義務です。義務を履行することで、サービスの公平性を保っています。 |
| B6 | 報酬残高 (Payments) | 報酬残高とは？ | レフリーとして獲得した未出金の報酬残高です。決済プラットフォームStripeを通じて指定した銀行口座に出金されます。 |
| B7 | 累計受取額 (Payments) | 累計受取額とは？ | これまでにレフリー業務で獲得した報酬の累計額です。 |

### Terminology notes

- **レフリー** is used consistently (matches `store-listing/ja/full_description.txt`). Existing slang has occasional `レフェリー` — those are not changed in this PR but new content uses `レフリー`.
- **判定** is used for the specific decision action by a referee (matches existing `judgement_*` slang). 「確認」 is used in Section 1 for the broader "third-party oversight" concept (matches store-listing tone).
- **Stripe** mentions include the inline qualifier "決済プラットフォーム" so first-time readers know what Stripe is.
- **出金** terminology pairs consistently: 「未出金の報酬残高」 + 「出金されます」 to avoid mixing 受取/出金 in the same sentence.

## Slang Placement

- **AppExplanationBottomSheet content** lives under a new top-level namespace (e.g., `appExplanation`) with sub-keys for sheet title, each of the 4 sections (title + body), and the learn-more link.
- **Help dialog content** co-locates with the feature it documents under a `help` sub-key. Profile/matching help nests under existing `matching.referee_availability` and `matching.referee_blocked_dates` (which already use snake_case). Payments help nests under existing `dashboard` (which uses camelCase). New keys follow each subtree's existing naming convention rather than enforcing a single style.
- **Shared label**: A common "閉じる" button label is reused across all help dialogs.

Exact key names are an implementation detail. English translation follows the existing slang workflow cadence and is not part of v1.0.

## Implementation Order

1. `BaseBottomSheet`, `BaseDialog`, `BaseSection.trailing` (base infrastructure)
2. `HelpIconButton` (consumes `BaseDialog`)
3. `AppExplanationBottomSheet` + `_ExplanationSectionTile` + slang content (consumes `BaseBottomSheet`)
4. LoginScreen wiring + Profile menu entry
5. `?` icon integrations on matching profile sections (`BaseSection.trailing`)
6. `?` icon integrations on payments summary cards (manual composition inside `BaseCard`)

Verification at each step: visual check on Android emulator, no regressions to existing screens.

## Future Considerations

- **Carousel migration**: When ready, swap `Column` → `PageView` in `_AppExplanationBody`. Add page indicator + Skip button. No data structure change required.
- **Refactor existing implementations**: After base widgets prove out, migrate `plan_selection_bottom_sheet`, `report_bottom_sheet`, `delete_account_confirmation_dialog`, and similar to consume base widgets. Tracked separately.
- **Auto-show on first launch**: If post-launch data shows the LoginScreen "PepperCheckとは？" link sees low engagement, revisit with a one-time auto-show + persistence flag.
- **Wider `?` icon coverage**: If closed-test feedback surfaces specific confusion on home/task screens, add `?` icons in follow-up PRs without further design work — the pattern is established here.
- **Apply "what + why" principle to other help content**: As more `?` icons are added, ensure body copy explains why a concept exists when non-obvious, not just what it is.

## Risks

- **Discoverability of "PepperCheckとは？" link**: Small low-emphasis link below the CTA may go unnoticed. If feedback shows low engagement, escalate post-launch (auto-show, larger placement, or move to a more prominent position).
- **Single-screen fit on small devices**: The compact horizontal layout is designed for the BottomSheet to fit without scrolling on common phones, but small devices (≤ 5") may still overflow. The underlying `SingleChildScrollView` is the fallback.
- **Visual regression on `BaseSection`**: When adding `trailing`, existing usages (no `trailing`) must render byte-identical to today. Verify on at least one existing section before declaring done.
- **Card/section growth from `?` icon**: A naive `IconButton` placement will inflate row height by ~24px. Verify that adding the `?` icon to an existing section/card preserves its current outer dimensions exactly. Spot-check by overlaying screenshots before/after.
