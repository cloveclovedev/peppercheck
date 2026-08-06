# Judgement Approve/Reject Flutter UI Design

**Related Issue:** #72 (Epic: Flutter Android) - MVP Features > Judgement: Implement approve/reject functionality

**Goal:** Add UI for referees to approve/reject evidence and display judgement results to both tasker and referee.

**Scope:** Flutter only. Backend RPC (`judge_evidence`) is already implemented.

---

## 1. JudgementSection Widget

Added to `task_detail_screen` as a new section.

**Display logic by state and role:**

| Condition | Display |
|-----------|---------|
| `in_review` + referee | Comment text field + Approve/Reject buttons (inline form) |
| `approved` / `rejected` + anyone | Status badge + comment (read-only) |
| Other states | Section hidden |

**Form (in_review + referee):**
- Multi-line text field (matching existing form styles)
- Two buttons side-by-side: Approve (primary) / Reject (error/destructive color)
- Loading state disables buttons during submission
- Comment is required (validated before submission)

**Result display (approved/rejected):**
- Status badge (approved: green, rejected: red)
- Referee comment as text

---

## 2. Data & Controller

**JudgementRepository** (`features/judgement/data/judgement_repository.dart`)
- Single method calling `judge_evidence` RPC

**JudgementController** (`features/judgement/presentation/controllers/judgement_controller.dart`)
- `@riverpod` + `AsyncNotifier<void>` pattern (same as `EvidenceController`)
- `submit()` calls repository, invalidates `taskProvider` on success

**Referee detection:**
- Compare `task.refereeRequests[].matchedRefereeId` with `currentUser.id` in the widget

---

## 3. Files

| Action | File |
|--------|------|
| Create | `features/judgement/data/judgement_repository.dart` |
| Create | `features/judgement/presentation/controllers/judgement_controller.dart` |
| Create | `features/judgement/presentation/widgets/judgement_section.dart` |
| Modify | `features/task/presentation/task_detail_screen.dart` |

---

## 4. Out of Scope

- Confirm functionality
- i18n (follow existing Slang patterns, add keys as needed)
- Flutter widget tests
