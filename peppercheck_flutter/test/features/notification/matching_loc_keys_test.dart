import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/notification/application/notification_text_resolver.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// The matching events the Go worker emits (backend design §8). The server
/// sends localization keys, never resolved text, so a key the app cannot
/// resolve would silently degrade to the generic fallback copy.
const _matchingKeys = [
  'notification_request_matched_tasker',
  'notification_task_assigned_referee',
  'notification_matching_reassigned_tasker',
  'notification_matching_cancelled_pending_tasker',
  'notification_matching_expired_refunded_tasker',
];

void main() {
  setUpAll(() => LocaleSettings.setLocale(AppLocale.ja));

  const taskTitle = 'My Task';
  const deadline = '2026-08-01T00:00:00Z';

  for (final key in _matchingKeys) {
    test('$key resolves to real copy carrying the task title', () {
      final text = resolveNotificationText(
        titleLocKey: '${key}_title',
        bodyLocKey: '${key}_body',
        // Argument ordering is the contract with the worker: [0] is the task
        // title, [1] the deadline.
        locArgs: const [taskTitle, deadline],
      );

      expect(text.title, isNotEmpty);
      expect(text.body, isNotEmpty);
      expect(text.title, isNot(t.notification.fallback_title));
      expect(text.body, isNot(t.notification.fallback_body));
      expect(text.body, contains(taskTitle));
    });
  }

  test('an unknown key falls back instead of throwing', () {
    final text = resolveNotificationText(
      titleLocKey: 'notification_not_a_real_event_tasker_title',
      bodyLocKey: 'notification_not_a_real_event_tasker_body',
      locArgs: const [taskTitle],
    );

    expect(text.title, t.notification.fallback_title);
    expect(text.body, t.notification.fallback_body);
  });

  test('missing loc args do not break resolution', () {
    final text = resolveNotificationText(
      titleLocKey: 'notification_request_matched_tasker_title',
      bodyLocKey: 'notification_request_matched_tasker_body',
    );

    expect(text.title, isNotEmpty);
    expect(text.body, isNotEmpty);
  });
}
