import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/domain/task_ordering.dart';

Task _task(String id, {String? dueDate, String? createdAt}) => Task(
  id: id,
  taskerId: 'u_tasker',
  title: id,
  status: 'open',
  dueDate: dueDate,
  createdAt: createdAt ?? '2026-07-01T00:00:00Z',
);

void main() {
  test('soonest deadline first', () {
    final sorted = sortedByDueDate([
      _task('later', dueDate: '2026-08-10T00:00:00Z'),
      _task('sooner', dueDate: '2026-08-01T00:00:00Z'),
    ]);

    expect(sorted.map((t) => t.id), ['sooner', 'later']);
  });

  test('tasks without a deadline sort last', () {
    final sorted = sortedByDueDate([
      _task('none'),
      _task('dated', dueDate: '2026-08-10T00:00:00Z'),
    ]);

    expect(sorted.map((t) => t.id), ['dated', 'none']);
  });

  test('oldest first within the same deadline', () {
    final sorted = sortedByDueDate([
      _task(
        'newer',
        dueDate: '2026-08-01T00:00:00Z',
        createdAt: '2026-07-20T00:00:00Z',
      ),
      _task(
        'older',
        dueDate: '2026-08-01T00:00:00Z',
        createdAt: '2026-07-01T00:00:00Z',
      ),
    ]);

    expect(sorted.map((t) => t.id), ['older', 'newer']);
  });

  test('leaves the input list untouched', () {
    final input = [
      _task('b', dueDate: '2026-08-10T00:00:00Z'),
      _task('a', dueDate: '2026-08-01T00:00:00Z'),
    ];

    sortedByDueDate(input);

    expect(input.map((t) => t.id), ['b', 'a']);
  });
}
