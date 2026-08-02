# Phase 4a — Follow-ups

Items surfaced during the Phase 4a (task authoring + matching) port that are
deliberately **not** implemented in 4a. Recorded so they can be picked up later
rather than silently carried or dropped. Companion to
`2026-07-25-phase4a-task-authoring-matching-design.md`.

## Dropped in 4a (removed dead / no-op code)

| Item | Why dropped | If revived |
|------|-------------|-----------|
| `premium` matching strategy | Never implemented: `process_matching` returns no match for `premium`, and `get_point_for_matching_strategy` rejects it. In practice it charges 2 points and always expires + refunds — a broken UX, not a feature. | Design a fresh advanced/premium matching tier; add a `matching_strategy` enum value + real logic. |
| `direct` matching strategy + `preferred_referee_id` | Never wired: the UI never sends `direct` and never sets `preferred_referee_id`; the cost function rejects non-standard. | Design a referee direct-nomination flow fresh; re-add the column + branch. |
| `matching_strategy` multi-value dimension | Collapsed to single value `standard` (the only live value). A single-value enum column is kept as a forward-compatible seam. | Add enum values + per-strategy logic when premium/direct are designed. |
| `matched` / `declined` referee-request states | Unreached in the auto-accept flow (matching jumps straight to `accepted`). | Reintroduce with the referee accept/decline flow (below). |
| `tasks.fee_amount` / `tasks.fee_currency` | Defined in the Flutter `Task` model but never read anywhere. Dead data. | Reintroduce with a paid-task / reward-amount feature (relate to Phase 5 reward). |
| KV `matching_config` table | Its only key (`min_due_date_interval_hours`) was removed by a later migration; the table is effectively empty. Replaced by the typed config table. | Add typed columns to the typed `matching_config` instead of a KV bag. |
| `detect_and_handle_referee_timeouts()` | Dead duplicate of the scheduled, live `detect_and_handle_review_timeouts()` (judgement domain). No cron entry, no callers. Name says "referee" but it detects review timeouts. | The live review-timeout detection is ported in 4c; do not resurrect this duplicate. |

## Intended-but-unbuilt / deferred features

| Item | Notes |
|------|-------|
| **Referee accept/decline flow** | Today matching auto-accepts (`pending → accepted`). The intended flow uses `matched` (worker matched, awaiting referee response) → `accepted` / `declined`. The async matching model makes this easier to add. Reintroduces the dropped enum states. |
| **Premium / advanced matching tier** | See dropped `premium`. Design fresh, not a port. |
| **`referee_availability` editing (is_accepting / max_concurrent)** | 4a adds the table + matching enforcement (no-op at defaults). The edit endpoint + UI belong to the imminent "accepting on/off + concurrency cap" feature. |
| **Server-side notification localization** | 4a keeps client-side FCM `loc_key` (reuses the app's i18n, tracks OS locale). Moving localization to Go (resolve text from a `profile.language` + a Go/JSON i18n catalog) gains app-release-free copy updates and richer formatting, at the cost of a second i18n catalog and a reliable user-language source. The `send_notification` job contract `(userID, key, args, data)` is identical either way, so this is a single isolated swap inside the notification service — no upstream changes. High-value; do post-port or as a dedicated small initiative. |
| **`task_` prefix drop for `evidences`** | 4a drops `task_referee_requests` → `referee_requests`. Apply the same to `task_evidences` → `evidences` in 4b. |
| **All-requests-expired task terminal state + tasker withdrawal** | An `open` task whose referee requests all expire (zero matched) stays `open` forever — 4c only closes on all-judgements-confirmed, and there is no tasker-facing withdraw/cancel for an open task. This gap exists in the current system too (4a preserves it), but it is a real UX hole surfaced in the 4a spec review. Needs a product decision at the 4a/4c boundary: auto-close/auto-fail when all requests expire, a tasker withdrawal action, or a new terminal task state. Partial expiry (some accepted, some expired) is consistent with 4c close-on-all-confirmed and needs no change. **Decide before 4c.** |
| **`max_concurrent_assignments` concurrency enforcement** | 4a adds the column + candidate-query filter (no-op at `NULL`). Enforcing the cap under concurrent matching (a `COUNT < cap` race a unique index cannot express) requires a per-referee `pg_advisory_xact_lock` + re-count in the match handler; build it with the availability-cap edit feature that turns the cap on (P4a-D16). |
| **Verify `min_due_date_interval_hours` enforcement** | The KV key was deleted; confirm where (if anywhere) the "minimum hours between now and due date for open tasks" rule currently lives, and fold any surviving threshold into the typed `matching_config` + the Go open-requirement validation. |

## Product signals (not code)

- **Point-based subscription reception** — a pre-test with acquaintances did not
  respond well to the points-for-matching subscription model. Port faithfully
  now; treat a monetization/UX rethink as a separate post-migration initiative.
  (See the operator memory note.)
