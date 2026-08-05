// Package judgement owns the judgement row keyed 1:1 to a referee request. In
// Phase 4a only the awaiting_evidence provisioning (create on match, delete on
// pre-evidence cancel) exists; the full lifecycle — evidence review, confirm,
// reopen, auto-confirm, and timeouts — arrives in Phase 4c.
package judgement

// StatusAwaitingEvidence is the only judgement status Phase 4a writes.
const StatusAwaitingEvidence = "awaiting_evidence"
