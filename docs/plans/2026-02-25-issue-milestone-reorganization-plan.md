# Issue/Milestone Reorganization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize GitHub issues and milestones from Epic-based to flat issue + milestone model.

**Architecture:** All operations are GitHub API calls via `gh` CLI. No code changes. Each task is a logical group of related `gh` commands with verification.

**Tech Stack:** GitHub CLI (`gh`)

**Design doc:** `docs/plans/2026-02-25-issue-milestone-reorganization-design.md`

---

### Task 1: Close completed milestone v0.2.0

**Step 1: Close v0.2.0**

```bash
gh api repos/{owner}/{repo}/milestones/1 -X PATCH -f state=closed
```

**Step 2: Verify**

```bash
gh api repos/{owner}/{repo}/milestones/1 --jq '{title, state}'
```

Expected: `{"title":"v0.2.0","state":"closed"}`

**Step 3: Commit (no code change — skip)**

No files changed. This is a GitHub-only operation.

---

### Task 2: Update due dates for active milestones

**Step 1: Update v0.3.0 due date to 2026-03-01**

```bash
gh api repos/{owner}/{repo}/milestones/2 -X PATCH -f due_on=2026-03-01T00:00:00Z
```

**Step 2: Update v0.4.0 due date to 2026-03-08**

```bash
gh api repos/{owner}/{repo}/milestones/3 -X PATCH -f due_on=2026-03-08T00:00:00Z
```

**Step 3: Update v1.0.0 due date to 2026-03-31**

```bash
gh api repos/{owner}/{repo}/milestones/4 -X PATCH -f due_on=2026-03-31T00:00:00Z
```

**Step 4: Update v1.1.0 due date to 2026-04-30**

```bash
gh api repos/{owner}/{repo}/milestones/6 -X PATCH -f due_on=2026-04-30T00:00:00Z
```

**Step 5: Verify all due dates**

```bash
gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.state=="open") | {title, due_on}'
```

Expected: v0.3.0 → 2026-03-01, v0.4.0 → 2026-03-08, v1.0.0 → 2026-03-31, v1.1.0 → 2026-04-30.

---

### Task 3: Delete future milestones (v1.3.0, v1.4.0, v1.5.0, v1.6.0)

Before deleting, any issues assigned to these milestones must have their milestone removed first. Currently:
- v1.3.0 (milestone 7): 0 open issues
- v1.4.0 (milestone 8): 1 open issue (#73 Epic: Profile v1)
- v1.5.0 (milestone 9): 1 open issue (#75 Epic: Nudge v1)
- v1.6.0 (milestone 10): 1 open issue (#74 Epic: Multi-lang)

**Step 1: Remove milestones from issues that will become backlog**

```bash
gh issue edit 73 --milestone ""
gh issue edit 74 --milestone ""
gh issue edit 75 --milestone ""
```

**Step 2: Delete milestones**

```bash
gh api repos/{owner}/{repo}/milestones/7 -X DELETE
gh api repos/{owner}/{repo}/milestones/8 -X DELETE
gh api repos/{owner}/{repo}/milestones/9 -X DELETE
gh api repos/{owner}/{repo}/milestones/10 -X DELETE
```

**Step 3: Verify only 4 milestones remain**

```bash
gh api repos/{owner}/{repo}/milestones --jq '.[] | {number, title, state}'
```

Expected: v0.2.0 (closed), v0.3.0, v0.4.0, v1.0.0, v1.1.0 only.

---

### Task 4: Convert Epic issues to regular issues

Remove `type/epic` label and add `type/feature` label on all Epic issues. Keep existing milestone assignments.

**Step 1: Relabel #21 (MVP release)**

```bash
gh issue edit 21 --remove-label "type/epic" --add-label "type/feature"
```

**Step 2: Relabel #70 (Freemium v1)**

```bash
gh issue edit 70 --remove-label "type/epic" --add-label "type/feature"
```

**Step 3: Relabel #71 (Flutter iOS)**

```bash
gh issue edit 71 --remove-label "type/epic" --add-label "type/feature"
```

**Step 4: Relabel #72 (Flutter Android — closed issue)**

```bash
gh issue edit 72 --remove-label "type/epic" --add-label "type/feature"
```

Note: #72 is currently closed. The user wants to keep it as a working checklist. Relabel only; do not reopen.

**Step 5: Relabel #73 (Profile v1)**

```bash
gh issue edit 73 --remove-label "type/epic" --add-label "type/feature"
```

**Step 6: Relabel #74 (Multi-lang/currency)**

```bash
gh issue edit 74 --remove-label "type/epic" --add-label "type/feature"
```

**Step 7: Relabel #75 (Nudge v1)**

```bash
gh issue edit 75 --remove-label "type/epic" --add-label "type/feature"
```

**Step 8: Verify no issues have type/epic label**

```bash
gh issue list --label "type/epic" --state all --json number,title
```

Expected: empty list `[]`.

---

### Task 5: Delete `type/epic` label

**Step 1: Delete label**

```bash
gh label delete "type/epic" --yes
```

**Step 2: Verify**

```bash
gh label list --json name --jq '.[].name' | grep epic
```

Expected: no output.

---

### Task 6: Assign milestones to unassigned issues

**Step 1: Assign quality/refactor issues to v1.0.0**

```bash
gh issue edit 253 --milestone "v1.0.0"
gh issue edit 255 --milestone "v1.0.0"
gh issue edit 257 --milestone "v1.0.0"
gh issue edit 260 --milestone "v1.0.0"
gh issue edit 218 --milestone "v1.0.0"
gh issue edit 183 --milestone "v1.0.0"
```

**Step 2: Verify — no issues should lack milestone except backlog (#215, #251, #252)**

```bash
gh issue list --state open --json number,title,milestone --jq '.[] | select(.milestone == null) | {number, title}'
```

Expected: only #215, #251, #252 remain without milestone.

---

### Task 7: Final verification

**Step 1: Full milestone summary**

```bash
gh api repos/{owner}/{repo}/milestones --jq '.[] | {title, state, due_on, open_issues, closed_issues}'
```

**Step 2: All open issues with their milestones**

```bash
gh issue list --state open --limit 100 --json number,title,milestone,labels --jq '.[] | {number, title, milestone: (.milestone.title // "BACKLOG"), labels: [.labels[].name]}'
```

**Step 3: Confirm no type/epic label exists**

```bash
gh label list --json name --jq '.[].name' | sort
```
