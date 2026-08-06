import 'task.dart';

/// Orders tasks the way both home lists are meant to read: soonest deadline
/// first, tasks without a deadline last, oldest first within a tie.
///
/// The Go API pages these lists newest-first (a keyset cursor over
/// `created_at`), so the deadline ordering is applied here, on the aggregated
/// list, rather than being lost in the migration off the Supabase queries that
/// used to sort by `due_date ASC NULLS LAST, created_at ASC`.
List<Task> sortedByDueDate(List<Task> tasks) {
  final sorted = [...tasks];
  sorted.sort((a, b) {
    final aDue = _parse(a.dueDate);
    final bDue = _parse(b.dueDate);
    if (aDue != null && bDue != null && aDue != bDue) {
      return aDue.compareTo(bDue);
    }
    if (aDue == null && bDue != null) return 1;
    if (aDue != null && bDue == null) return -1;

    final aCreated = _parse(a.createdAt);
    final bCreated = _parse(b.createdAt);
    if (aCreated == null || bCreated == null) return 0;
    return aCreated.compareTo(bCreated);
  });
  return sorted;
}

DateTime? _parse(String? value) =>
    value == null ? null : DateTime.tryParse(value);
