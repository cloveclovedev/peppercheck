import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// Resolves FCM title_loc_key / body_loc_key to localized Dart strings.
///
/// FCM sends notification messages with loc_keys that the platform resolves
/// for background/terminated notifications (from strings.xml / Localizable.strings).
/// For foreground notifications, we need to resolve them in Dart.
({String title, String body}) resolveNotificationText({
  String? titleLocKey,
  String? bodyLocKey,
  List<String>? locArgs,
}) {
  final taskTitle = (locArgs != null && locArgs.isNotEmpty) ? locArgs[0] : '';

  final title = _resolveKey(titleLocKey, taskTitle) ?? t.notification.fallback_title;
  final body = _resolveKey(bodyLocKey, taskTitle) ?? t.notification.fallback_body;

  return (title: title, body: body);
}

String? _resolveKey(String? locKey, String taskTitle) {
  if (locKey == null) return null;

  switch (locKey) {
    case 'notification_evidence_timeout_title':
      return t.notification.evidence_timeout_title;
    case 'notification_evidence_timeout_body':
      return t.notification.evidence_timeout_body(taskTitle: taskTitle);
    case 'notification_evidence_timeout_reward_title':
      return t.notification.evidence_timeout_reward_title;
    case 'notification_evidence_timeout_reward_body':
      return t.notification.evidence_timeout_reward_body(taskTitle: taskTitle);
    case 'notification_request_matched_title':
      return t.notification.request_matched_title;
    case 'notification_request_matched_body':
      return t.notification.request_matched_body(taskTitle: taskTitle);
    case 'notification_referee_assigned_title':
      return t.notification.referee_assigned_title;
    case 'notification_referee_assigned_body':
      return t.notification.referee_assigned_body(taskTitle: taskTitle);
    case 'notification_request_accepted_title':
      return t.notification.request_accepted_title;
    case 'notification_request_accepted_body':
      return t.notification.request_accepted_body;
    case 'notification_evidence_submitted_title':
      return t.notification.evidence_submitted_title;
    case 'notification_evidence_submitted_body':
      return t.notification.evidence_submitted_body(taskTitle: taskTitle);
    case 'notification_evidence_updated_title':
      return t.notification.evidence_updated_title;
    case 'notification_evidence_updated_body':
      return t.notification.evidence_updated_body(taskTitle: taskTitle);
    default:
      return null;
  }
}
