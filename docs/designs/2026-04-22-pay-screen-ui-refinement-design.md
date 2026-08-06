# Pay Screen UI Refinement Design

## Date

2026-04-22

## Problem

The Pay screen has several UI inconsistencies that hurt visual cohesion:

1. **Inconsistent card sizing** - Summary cards (radius 8, icon 16px), subscription status card (radius 12, icon 32px), and plan cards (radius 20, icon 24px) all differ in sizing, padding, and proportions.
2. **Colored card backgrounds are distracting** - Trial point cards (green background) and obligation cards (yellow background) create a "flickering" effect that makes the screen feel busy.
3. **Subscription section wastes space** - Showing all plan cards (Light, Standard, Premium) inline takes excessive vertical space. A single CTA that opens a bottom sheet is more aligned with Material Design 3 best practices.

## Design

### 1. BaseCard Common Widget

**Location:** `common_widgets/base_card.dart`

A thin container widget that provides the visual shell (background, border, radius, padding, tap handling) while leaving content entirely to the `child`. Pairs with `BaseSection` as the app's foundational UI building blocks.

**Default style:**

| Property | Default | Source |
|----------|---------|--------|
| borderRadius | `AppSizes.radiusMedium` (12.0) | Matches TaskCard, TimeSlotCard |
| padding | horizontal 12, vertical 4 | Matches TaskCard |
| backgroundColor | `AppColors.backgroundLight` | Matches current summary cards |
| borderColor | `AppColors.border` (1px) | Matches current summary cards |

**Customizable properties:**
- `backgroundColor` - override background (e.g., `backgroundWhite` for TaskCard-style)
- `borderColor` - override border color, pass `null` for no border (e.g., TaskCard-style)
- `borderRadius` - override radius
- `padding` - override padding
- `onTap` - when provided, wraps content in `Material` + `InkWell` for ripple effect; otherwise renders a plain `Container`

**Design goal:** Any existing card in the app (TaskCard, TimeSlotCard, SummaryCard, etc.) should be expressible through BaseCard by passing the appropriate attributes, without changing its visual appearance. This enables incremental migration.

### 2. Card Action Button Pattern

A reusable button pattern for action buttons placed inside cards (e.g., "Change Plan" button in the subscription status card).

**Style:**
- FilledTonalButton (light background tint + colored text)
- Text: `bodySmall` size
- Color and label are customizable
- Compact sizing (minimal internal padding)

**Implementation:** Either as a factory/helper within `BaseCard`, or as a separate reusable widget (e.g., `BaseCardAction`). Decision deferred to implementation.

### 3. Payment Summary Section Changes

**Goal:** Unify all summary cards to BaseCard defaults; remove colored backgrounds.

**Before -> After for each card:**

| Card | Before | After |
|------|--------|-------|
| Points (regular) | bg: backgroundLight, border: border, icon: 16px green | BaseCard default, icon: 20px green, value text: green |
| Points (trial) | bg: greenLight 30%, border: green 50%, icon: 16px | BaseCard default (no green bg/border), icon: 20px green, value text: green |
| Obligations | bg: yellowLight 30%, border: yellow 50%, icon: 16px | BaseCard default (no yellow bg/border), icon: 20px yellow, value text: yellow |
| Reward Balance | No icon, in Row (left) | Add icon `account_balance_wallet` 20px, keep in Row |
| Total Earned | No icon, in Row (right) | Add icon `trending_up` 20px, keep in Row |
| Payout Info | No icon, label+value rows | Add icon `send` 20px |

**Color expression:** Only icon color and value text color carry accent colors. Background and border are always the shared default.

**Icon size:** Unified to 20px (matching TaskCard's `taskCardIconSize`).

**Layout:** Reward Balance and Total Earned remain in a horizontal `Row`. If cramped with icons, revisit in implementation.

### 4. Subscription Section Changes

**Goal:** Replace inline plan card list with a compact status card + Modal BottomSheet.

#### 4a. Status Card with Inline CTA

Replace the current `_StatusDisplay` (icon 32px, radius 12) + `_PlanCardList` with a single `BaseCard`:

```
+--------------------------------------------------+
| [star 20px]  Plan Name          [Change Plan btn] |
|              Renews: 2026/05/01                   |
+--------------------------------------------------+
```

**Layout:**
- Left: Star icon (20px) in plan color (or textMuted if not subscribed)
- Center (expanded): Plan name (`bodySmall` bold) + subtitle (`bodySmall` textSecondary)
- Right: FilledTonalButton (card action button pattern)

**Button label by state:**

| State | Label | Color |
|-------|-------|-------|
| Not subscribed | Choose Plan (プランを選ぶ) | accentBlue |
| Active subscription | Change Plan (プランを変更) | accentBlue |
| Payment issue (not subscribed) | Check Plan (確認する) | textError |
| Payment issue (active) | Check Plan (確認する) | textError |

**Subtitle by state:**
- Active: "Renews: {date}" or "Canceled until {date}"
- Not subscribed: none
- Payment issue: error message

#### 4b. Modal BottomSheet for Plan Selection

Tapping the CTA button opens a `showModalBottomSheet`:

```
-------------------------------
    --- (drag handle)

    Choose a Plan

    +-------------------------+
    | [star] Light    JPY300  |   <- current plan: greyed out
    +-------------------------+
    +-------------------------+
    | [star] Standard JPY500  |
    +-------------------------+
    +-------------------------+
    | [star] Premium  JPY800  |
    +-------------------------+

    Cancel via Google Play
-------------------------------
```

**Structure:**
- Drag handle (M3 convention)
- Title: "Choose a Plan" (プランを選ぶ) - `titleSmall` bold
- Plan cards: Each uses `BaseCard` with `onTap`
  - Current plan: greyed out (backgroundDark 30%, textMuted, disabled)
  - Other plans: default style, star icon in plan color, price in accentBlue bold
  - Icon: 20px star, plan-specific color
- Cancel link: only shown for active subscribers, small text at bottom (`bodySmall`, textSecondary)
- Returns selected plan via `Future<ProductDetails?>`

#### 4c. Removed Components

- `_PlanCardList` widget - no longer rendered on the main screen
- `PlanCard` widget - replaced by BaseCard-based cards inside the BottomSheet (PlanCard file can be refactored or removed)

### 5. Scope

**In scope (this PR):**
- Create `BaseCard` widget in `common_widgets/`
- Create card action button pattern (reusable)
- Refactor `PaymentSummarySection` to use `BaseCard`
- Refactor `SubscriptionSection` to status card + BottomSheet
- Update `AppSizes` if new constants are needed

**Out of scope (future):**
- Migrating Home screen cards (TaskCard) to BaseCard
- Migrating Profile screen cards (TimeSlotCard, BlockedDateCard) to BaseCard
- Migrating Judgement screen cards to BaseCard
- Responsive horizontal to vertical layout for reward cards

## Testing

- Visual verification on Android emulator
- Verify all subscription states render correctly (not subscribed, active, payment issue, canceled)
- Verify BottomSheet opens, displays plans, returns selection
- Verify purchase flow still works end-to-end after BottomSheet selection
- Verify pull-to-refresh still updates summary and subscription data
