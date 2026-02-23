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
    case 'notification_evidence_timeout_tasker_title':
      return t.notification.evidence_timeout_tasker_title;
    case 'notification_evidence_timeout_tasker_body':
      return t.notification.evidence_timeout_tasker_body(taskTitle: taskTitle);
    case 'notification_evidence_timeout_referee_title':
      return t.notification.evidence_timeout_referee_title;
    case 'notification_evidence_timeout_referee_body':
      return t.notification.evidence_timeout_referee_body(taskTitle: taskTitle);
    case 'notification_request_matched_tasker_title':
      return t.notification.request_matched_tasker_title;
    case 'notification_request_matched_tasker_body':
      return t.notification.request_matched_tasker_body(taskTitle: taskTitle);
    case 'notification_task_assigned_referee_title':
      return t.notification.task_assigned_referee_title;
    case 'notification_task_assigned_referee_body':
      return t.notification.task_assigned_referee_body(taskTitle: taskTitle);
    case 'notification_request_accepted_title':
      return t.notification.request_accepted_title;
    case 'notification_request_accepted_body':
      return t.notification.request_accepted_body;
    case 'notification_evidence_submitted_referee_title':
      return t.notification.evidence_submitted_referee_title;
    case 'notification_evidence_submitted_referee_body':
      return t.notification.evidence_submitted_referee_body(taskTitle: taskTitle);
    case 'notification_evidence_updated_referee_title':
      return t.notification.evidence_updated_referee_title;
    case 'notification_evidence_updated_referee_body':
      return t.notification.evidence_updated_referee_body(taskTitle: taskTitle);
    case 'notification_evidence_resubmitted_referee_title':
      return t.notification.evidence_resubmitted_referee_title;
    case 'notification_evidence_resubmitted_referee_body':
      return t.notification.evidence_resubmitted_referee_body(taskTitle: taskTitle);
    case 'notification_review_timeout_tasker_title':
      return t.notification.review_timeout_tasker_title;
    case 'notification_review_timeout_tasker_body':
      return t.notification.review_timeout_tasker_body(taskTitle: taskTitle);
    case 'notification_review_timeout_referee_title':
      return t.notification.review_timeout_referee_title;
    case 'notification_review_timeout_referee_body':
      return t.notification.review_timeout_referee_body(taskTitle: taskTitle);
    case 'notification_auto_confirm_tasker_title':
      return t.notification.auto_confirm_tasker_title;
    case 'notification_auto_confirm_tasker_body':
      return t.notification.auto_confirm_tasker_body(taskTitle: taskTitle);
    case 'notification_auto_confirm_referee_title':
      return t.notification.auto_confirm_referee_title;
    case 'notification_auto_confirm_referee_body':
      return t.notification.auto_confirm_referee_body(taskTitle: taskTitle);
    default:
      return null;
  }
}
