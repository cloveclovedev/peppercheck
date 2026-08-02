# Confirm Judgement Flutter UI Design

## Overview

Add Flutter UI for Taskers to confirm referee judgement results and provide binary ratings (fair/unfair). The backend RPC `confirm_judgement_and_rate_referee(p_judgement_id, p_is_positive, p_comment)` is already implemented and merged.

## UI Design

### Placement

Add a confirm area conditionally inside the existing `JudgementSection` > `_buildResultCard`.

### Display Conditions

- Current user is the Tasker (`currentUser == task.taskerId`)
- Judgement is not yet confirmed (`judgement.isConfirmed == false`)
- Judgement has a terminal status (`judgement.status in ['approved', 'rejected']`)

### Layout

Append the following below the existing result card content:

```
┌──────────────────────────────────────┐
│ [Avatar] Approved / Rejected         │  ← existing
│          Comment text                │  ← existing
│──────────────────────────────────────│
│  この判定は適切でしたか？             │  ← new
│  (Was this a fair judgement?)         │
│                                      │
│   [👍 適切]        [👎 不適切]        │
│   (Fair)           (Unfair)          │
│                                      │
│  コメント（任意）                     │
│  [                                ]  │
│                                      │
│  [          確認する               ]  │
└──────────────────────────────────────┘
```

### Confirmed State

Once confirmed, the confirm area (question, buttons, comment, submit) is hidden. Instead, a green checkmark icon is displayed at the trailing end of the result card row to indicate confirmed status:

```
┌──────────────────────────────────────┐
│ [Avatar] Approved         [✓ green]  │
│          Comment text                │
└──────────────────────────────────────┘
```

The checkmark uses `Icons.check_circle` in `AppColors.accentGreen`.

### Binary Rating UI

- Thumbs up/down icons (Material Icons: `thumb_up` / `thumb_down`)
- Labels: 適切 (Fair) / 不適切 (Unfair)
- Unselected state: outlined icon, neutral color
- Selected positive: filled icon, green
- Selected negative: filled icon, red/orange (not aggressive)
- Radio behavior (only one selectable at a time)

### i18n Strings (Japanese)

Added under `task.judgement.confirm`:

```json
"confirm": {
  "question": "この判定は適切でしたか？",
  "fair": "適切",
  "unfair": "不適切",
  "comment": "コメント（任意）",
  "submit": "確認する",
  "success": "判定を確認しました"
}
```

## Architecture

### Files to Modify

| File | Change |
|------|--------|
| `judgement_repository.dart` | Add `confirmJudgement()` method calling the RPC |
| `judgement_controller.dart` | Add `confirmJudgement()` action |
| `judgement_section.dart` | Add `_buildConfirmArea()`, confirmed checkmark, Tasker detection |
| `ja.i18n.json` | Add confirm-related strings |

### Data Flow

```
User selects Fair/Unfair → local state (isPositive: bool?)
User taps Confirm → JudgementController.confirmJudgement()
  → JudgementRepository.confirmJudgement(judgementId, isPositive, comment)
    → Supabase RPC: confirm_judgement_and_rate_referee
  → invalidate taskProvider → UI refreshes
  → judgement.isConfirmed == true → confirm area replaced by checkmark
```

## UX Decisions

Based on UX research (Netflix, YouTube, Uber binary rating patterns):

- **Question framing**: Evaluates the outcome ("Was this a fair judgement?"), not the person. This reduces social pressure and encourages honest feedback.
- **Binary choice**: Thumbs up/down is universally understood. Netflix saw 200% more ratings after switching from 5-star to binary.
- **Optional comment**: Keeps the interaction low-cost. Comment field appears but is not required.
- **Integrated as "confirmation"**: The rating feels like a natural part of confirming the judgement, not a separate punitive action.
- **Confirmed indicator**: Green checkmark on the result card provides clear visual feedback that this judgement has been confirmed.
- **Post-submit feedback**: SnackBar with success message.
