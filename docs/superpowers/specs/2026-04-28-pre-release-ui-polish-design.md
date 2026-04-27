# Pre-release UI polish — design

Date: 2026-04-28
Scope: PepperCheck Flutter app, pre-release polish based on real-device testing

## Goal

Tighten Japanese copy, navigation labels, and small UI inconsistencies that surfaced during pre-release real-device testing. Each concern stays small enough to ship as an isolated PR.

## Non-goals

- Adding an English locale (the app currently ships Japanese only — `baseLocale: AppLocale.ja`)
- Adding a "become a referee" call-to-action on the Wallet screen (deferred — needs wider scope discussion)
- Replacing the task card amount with consumed-points display (tracked as a separate GitHub issue)
- Renaming the `billing/` Flutter feature directory to `point/` (existing tech-debt, separate PR)

## Decisions

### 1. Unify "レフェリー" → "レフリー"

The codebase mixes two transliterations. "レフリー" appears 24 times (dashboard, notifications, help text); "レフェリー" appears 6 times (billing, account-deletion strings).

**Decision:** Unify to "レフリー" everywhere.

**Rationale:** Already the majority spelling, shorter for mobile UI, matches the casual tone of the product.

**Files:** `peppercheck_flutter/assets/i18n/ja.i18n.json` (6 value replacements).

### 2. Navigation: keep English labels, Japanese AppBar titles

Current state is mixed: bottom-nav labels are English ("Home" / "Payments" / "Profile"), AppBar titles are inconsistent — Home and Payments both render English ("Home" / "Payments"), only Profile renders Japanese ("プロフィール").

**Decision:** Bottom-nav stays English (intentional aesthetic — confirmed during brainstorm). AppBar titles all become Japanese. Profile's existing pattern is the model.

| Surface | Key | Before | After |
|---|---|---|---|
| Bottom nav (Home) | `nav.home` | "Home" | "Home" (unchanged) |
| Bottom nav (Payments→Wallet) | `nav.payments` | "Payments" | **"Wallet"** |
| Bottom nav (Profile) | `nav.profile` | "Profile" | "Profile" (unchanged) |
| Bottom nav icon (Wallet) | code | `Icons.payments` | **`Icons.account_balance_wallet`** |
| AppBar (Home) | `home.title` | "Home" | **"ホーム"** |
| AppBar (Wallet) | new `dashboard.title` | (uses `nav.payments`) | **"ウォレット"** |
| AppBar (Profile) | `profile.title` | "プロフィール" | "プロフィール" (unchanged) |

**Rationale for "Wallet" / "ウォレット":** The screen is balance-centric (point balance is the lead UI), and rewards are *received* — "Payments" implies outgoing money, which clashes with both. "Wallet" matches the domain (LINE Wallet, Apple/Google Wallet, Kyash) and accommodates future scope (subscription, withdrawal settings). Icon must update to keep label/icon consistent.

**i18n key choice:** Add `dashboard.title` rather than a new `payments.title` top-level — the screen is internally `payment_dashboard` and uses the `dashboard.*` namespace already.

**Files:**
- `peppercheck_flutter/assets/i18n/ja.i18n.json` (4 value changes, 1 new key)
- `peppercheck_flutter/lib/common_widgets/app_scaffold.dart` (icon)
- `peppercheck_flutter/lib/features/payment_dashboard/presentation/payment_dashboard_screen.dart` (AppBar key swap: `t.nav.payments` → `t.dashboard.title`)

### 3. Home task card polish

Two issues: the legacy yen amount (`¥${task.feeAmount}`) is a pre-subscription artifact and should be removed; the date format `MM/dd H:mm` ("04/30 14:45") feels unnatural in Japanese where leading zeros on month/day are unusual.

**Decisions:**
- Remove the `¥${task.feeAmount}` row entirely (no replacement). A consumed-points alternative is tracked as a separate issue and may land later.
- Change date format `MM/dd H:mm` → `M/d H:mm` (e.g., "4/30 14:45").

**Files:** `peppercheck_flutter/lib/features/home/presentation/widgets/task_card.dart` (lines 21, 63).

### 4. Home section title: "自分のタスク" → "タスク"

The current label feels stilted in Japanese. The counterpart section is "判定依頼" (referee-side tasks), so "タスク" alone communicates ownership through contrast.

**Decision:** Rename to "タスク". Reject "マイタスク" (slightly tacky) and "わたしのタスク" (too soft for the world).

**Files:** `peppercheck_flutter/assets/i18n/ja.i18n.json` (`home.myTasks` value).

### 5. Wallet summary section title: "サマリー" → "ポイント・報酬"

"サマリー" alone doesn't say what is being summarized. The section is the screen-level lead and lists points + rewards.

**Decision:** Rename to "ポイント・報酬". The section is itself the summary view, so the word "サマリー" is redundant.

**Files:** `peppercheck_flutter/assets/i18n/ja.i18n.json` (`dashboard.paymentSummary` value).

### 6. Wallet: always-show reward cards (¥0 for empty state)

Currently `payment_summary_section.dart:99` hides the reward-balance and cumulative-earnings cards when `summary.rewards == null` (no referee data). This creates an asymmetric layout (points always shown, rewards conditional) and fails to surface the "you can earn here" mental model for non-referees.

**Decision:**
- Reward-balance card and cumulative-earnings card render unconditionally. When `summary.rewards == null`, both display `¥0`.
- Eliminate the `'—'` placeholder used for `totalEarnedCurrency == null`; render `¥0` instead.
- When `summary.rewards == null`, format the 0 amount with `currencyCode = 'JPY'` and `currencyExponent = 0` inline. Multi-currency support is a future goal (see Out of scope) but no forward-design marker is added in this PR — `lib/app/config/`'s conventions are not yet established and adding a new constants file there is a bigger decision than the marker would justify.

**Rationale:** Symmetric layout matches the points card's always-on behavior. The constant 0-yen presence acts as a soft prompt that referee participation has earnings; the explicit referee-registration CTA was considered but deferred to a separate scope.

**Files:** `peppercheck_flutter/lib/features/payment_dashboard/presentation/widgets/payment_summary_section.dart`

## PR plan

The user requested the changes ship as separate PRs to keep reviews tight. Proposed split:

| # | Title | Decisions covered |
|---|---|---|
| 1 | `chore(flutter): unify レフェリー to レフリー` | §1 |
| 2 | `feat(flutter): rename Payments to Wallet and apply Japanese AppBar titles` | §2 |
| 3 | `chore(flutter): polish home task card and section title` | §3, §4 |
| 4 | `feat(flutter): always-show reward cards on wallet summary` | §5, §6 |

PRs 1 and 3 are pure copy/format changes with no logic. PR 2 touches the icon import and one screen's AppBar wiring. PR 4 changes rendering logic and removes the `'—'` fallback.

Each PR must regenerate `gen/slang/strings.g.dart` after editing `ja.i18n.json` and verify `flutter build apk --debug -t lib/main_debug.dart` succeeds.

## Manual verification (per PR)

- Launch debug build on device/emulator
- Navigate Home → Wallet → Profile and confirm bottom-nav labels and AppBar titles match the table in §2
- Home: confirm task card has no yen line and date renders as `M/d H:mm`; confirm section header reads "タスク"
- Wallet: confirm summary header reads "ポイント・報酬"; for a fresh account with no referee data, confirm both reward cards show "¥0"; confirm payout row stays hidden when balance is 0
- Search source for `レフェリー` after PR 1 — should return zero hits

## Out of scope (tracked elsewhere)

- Replace removed yen line with consumed-points display: [#367](https://github.com/cloveclovedev/peppercheck/issues/367)
- Wallet "become a referee" CTA: needs separate brainstorm (qualification check, copy, animation/visual scope)
- i18n key namespace cleanup (mixed `billing` / `dashboard` / `nav` / `home` / `profile` conventions across screens): not in scope; track as future tech-debt PR if desired
- Multi-currency forward design (currency source, propagation, data migration): separate brainstorm needed; `lib/app/config/`'s conventions should be settled first before introducing currency-related shared constants there
