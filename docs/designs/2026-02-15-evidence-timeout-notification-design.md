# Evidence Timeout Notification Design

## Overview

Add push notification support for evidence timeout events, including:
1. Platform localization strings for notification templates
2. Dart-side i18n strings for foreground notification display
3. `flutter_local_notifications` for foreground notification display
4. FCM tap handlers for background/terminated/foreground notification navigation
5. Router extension to support task ID-based navigation from notifications

## Context

The backend already sends two notification events via `notify_event()`:
- `notification_evidence_timeout` → tasker (evidence timed out, points consumed)
- `notification_evidence_timeout_reward` → referee (reward granted)

The Edge Function (`send-notification/index.ts`) sends FCM messages with `title_loc_key`/`body_loc_key` for platform-level localization. The Flutter app currently logs foreground messages but does not display them or handle notification taps.

## Architecture

### Notification Display by App State

| App State | Mechanism | Text Resolution |
|-----------|-----------|-----------------|
| Background | Platform (Android/iOS) displays FCM notification | Platform resolves `title_loc_key` from `strings.xml`/`Localizable.strings` |
| Terminated | Same as background | Same as background |
| Foreground | `flutter_local_notifications` shows local notification | Dart-side i18n (slang) resolves `titleLocKey` |

### Notification Tap Navigation

| App State | Handler | Navigation |
|-----------|---------|------------|
| Background → tap | `FirebaseMessaging.onMessageOpenedApp` | Extract `task_id` from `message.data` → `router.go('/task_detail/$taskId')` |
| Terminated → tap | `FirebaseMessaging.instance.getInitialMessage()` | Same extraction and navigation |
| Foreground → tap | `flutter_local_notifications` `onDidReceiveNotificationResponse` | Extract `task_id` from notification payload → same navigation |

## Component Changes

### 1. Notification Templates (Platform Resources)

**Android `strings.xml` (English)**:
```xml
<string name="notification_evidence_timeout_title">Evidence Timeout</string>
<string name="notification_evidence_timeout_body">Your task "%1$s" has timed out due to missing evidence. Points have been consumed.</string>
<string name="notification_evidence_timeout_reward_title">Reward Earned</string>
<string name="notification_evidence_timeout_reward_body">You earned a reward for task "%1$s" due to evidence timeout.</string>
```

**Android `strings.xml` (Japanese)**:
```xml
<string name="notification_evidence_timeout_title">エビデンス期限切れ</string>
<string name="notification_evidence_timeout_body">タスク「%1$s」のエビデンス提出期限が過ぎました。ポイントが消費されました。</string>
<string name="notification_evidence_timeout_reward_title">報酬獲得</string>
<string name="notification_evidence_timeout_reward_body">タスク「%1$s」のエビデンス期限切れにより報酬を獲得しました。</string>
```

**iOS `Localizable.strings` (English)**:
```
"notification_evidence_timeout_title" = "Evidence Timeout";
"notification_evidence_timeout_body" = "Your task \"%@\" has timed out due to missing evidence. Points have been consumed.";
"notification_evidence_timeout_reward_title" = "Reward Earned";
"notification_evidence_timeout_reward_body" = "You earned a reward for task \"%@\" due to evidence timeout.";
```

**iOS `Localizable.strings` (Japanese)**:
```
"notification_evidence_timeout_title" = "エビデンス期限切れ";
"notification_evidence_timeout_body" = "タスク「%@」のエビデンス提出期限が過ぎました。ポイントが消費されました。";
"notification_evidence_timeout_reward_title" = "報酬獲得";
"notification_evidence_timeout_reward_body" = "タスク「%@」のエビデンス期限切れにより報酬を獲得しました。";
```

### 2. Dart-side i18n (slang)

Add notification strings to `ja.i18n.json` for foreground notification text resolution:

```json
"notification": {
  "evidence_timeout_title": "エビデンス期限切れ",
  "evidence_timeout_body": "タスク「$taskTitle」のエビデンス提出期限が過ぎました。ポイントが消費されました。",
  "evidence_timeout_reward_title": "報酬獲得",
  "evidence_timeout_reward_body": "タスク「$taskTitle」のエビデンス期限切れにより報酬を獲得しました。",
  "request_matched_title": "マッチング成立！",
  "request_matched_body": "あなたのタスク「$taskTitle」のレフリーが見つかりました。",
  "referee_assigned_title": "新しい担当タスク",
  "referee_assigned_body": "タスク「$taskTitle」の担当レフリーに選ばれました。",
  "request_accepted_title": "リクエスト承認",
  "request_accepted_body": "リクエストが承認されました。",
  "evidence_submitted_title": "エビデンス提出",
  "evidence_submitted_body": "$taskTitleさんが新しいエビデンスを提出しました。",
  "evidence_updated_title": "エビデンス更新",
  "evidence_updated_body": "$taskTitleさんがエビデンスを更新しました。",
  "fallback_title": "お知らせ",
  "fallback_body": "新しい通知があります。"
}
```

### 3. flutter_local_notifications Setup

**Package**: Add `flutter_local_notifications` to `pubspec.yaml`.

**Initialization** (in `FcmService.initialize()`):
- Create `FlutterLocalNotificationsPlugin` instance
- Configure Android: `AndroidInitializationSettings('@mipmap/ic_launcher')`
- Configure notification channel: `high_importance_channel` with HIGH importance
- Set `onDidReceiveNotificationResponse` callback for tap handling

### 4. FCM Service Changes (`fcm_service.dart`)

**`onMessage` handler (foreground)**:
1. Receive `RemoteMessage`
2. Extract `titleLocKey` / `bodyLocKey` from `message.notification`
3. Map loc_key to slang i18n string (e.g., `notification_evidence_timeout_title` → `t.notification.evidence_timeout_title`)
4. Substitute `body_loc_args` (task title) into the string
5. Show local notification via `flutter_local_notifications` with `task_id` in payload

**`onMessageOpenedApp` handler (background tap)**:
1. Extract `task_id` from `message.data`
2. Navigate to `/task_detail/$taskId` via `GoRouter`

**`getInitialMessage()` handler (terminated tap)**:
1. Check for initial message on startup
2. Same navigation logic as `onMessageOpenedApp`

**`onDidReceiveNotificationResponse` handler (foreground local notification tap)**:
1. Extract `task_id` from notification payload
2. Same navigation logic

### 5. Router Extension (`app_router.dart`)

**Change route** from `/task_detail` to `/task_detail/:taskId`:

```dart
GoRoute(
  path: '/task_detail/:taskId',
  builder: (context, state) {
    final taskId = state.pathParameters['taskId']!;
    final task = state.extra as Task?;
    return TaskDetailScreen(taskId: taskId, initialTask: task);
  },
),
```

### 6. TaskDetailScreen Changes

- Constructor: `TaskDetailScreen({required String taskId, Task? initialTask})`
- When `initialTask` is provided: display immediately, still watch `taskProvider(taskId)` for updates
- When `initialTask` is null (notification tap): show loading → fetch via `taskProvider(taskId)` → display

### 7. Home Screen Navigation Update

Update all `context.go('/task_detail', extra: task)` calls to `context.go('/task_detail/${task.id}', extra: task)`.

## Data Flow

```
Backend trigger (on evidence_timeout)
  → notify_event(user_id, 'notification_evidence_timeout', [task_title], {task_id, judgement_id})
  → Edge Function (send-notification)
  → FCM with title_loc_key + data.task_id
  → Device receives push
  → Background: Platform shows notification with localized text
  → Foreground: onMessage → Dart i18n resolve → flutter_local_notifications
  → User taps notification
  → Extract task_id from data/payload
  → Navigate to /task_detail/:taskId
  → TaskDetailScreen fetches and displays task
```

## Scope

This implementation is generic - it handles ALL notification types with `task_id` in data, not just evidence timeout. Future notification types automatically benefit from the tap-to-navigate behavior.

## Out of Scope

- Home screen dynamic refresh / real-time updates
- Unread notification badge
- Notification history / inbox
- iOS-specific foreground presentation options
