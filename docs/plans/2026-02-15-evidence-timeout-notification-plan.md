# Evidence Timeout Notification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add push notification templates for evidence timeout events, display foreground notifications via `flutter_local_notifications`, and handle notification taps to navigate to the task detail screen.

**Architecture:** Platform localization strings handle background/terminated notification display. Dart-side i18n (slang) resolves notification text for foreground display via `flutter_local_notifications`. FCM tap handlers (`onMessageOpenedApp`, `getInitialMessage`, `onDidReceiveNotificationResponse`) extract `task_id` from notification data and navigate to `/task_detail/:taskId`. The router is extended to support path-parameter-based navigation alongside the existing `extra`-based approach.

**Tech Stack:** Flutter, firebase_messaging, flutter_local_notifications, go_router, slang (i18n), Riverpod

**Design doc:** `docs/plans/2026-02-15-evidence-timeout-notification-design.md`

---

### Task 1: Add notification templates to platform localization resources

**Files:**
- Modify: `peppercheck_flutter/android/app/src/main/res/values/strings.xml`
- Modify: `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`
- Modify: `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings`
- Modify: `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings`

**Step 1: Add English Android strings**

In `peppercheck_flutter/android/app/src/main/res/values/strings.xml`, add before `</resources>`:

```xml
    <string name="notification_evidence_timeout_title">Evidence Timeout</string>
    <string name="notification_evidence_timeout_body">Your task "%1$s" has timed out due to missing evidence. Points have been consumed.</string>
    <string name="notification_evidence_timeout_reward_title">Reward Earned</string>
    <string name="notification_evidence_timeout_reward_body">You earned a reward for task "%1$s" due to evidence timeout.</string>
```

**Step 2: Add Japanese Android strings**

In `peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml`, add before `</resources>`:

```xml
    <string name="notification_evidence_timeout_title">エビデンス期限切れ</string>
    <string name="notification_evidence_timeout_body">タスク「%1$s」のエビデンス提出期限が過ぎました。ポイントが消費されました。</string>
    <string name="notification_evidence_timeout_reward_title">報酬獲得</string>
    <string name="notification_evidence_timeout_reward_body">タスク「%1$s」のエビデンス期限切れにより報酬を獲得しました。</string>
```

**Step 3: Add English iOS strings**

In `peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings`, add at the end:

```
"notification_evidence_timeout_title" = "Evidence Timeout";
"notification_evidence_timeout_body" = "Your task \"%@\" has timed out due to missing evidence. Points have been consumed.";
"notification_evidence_timeout_reward_title" = "Reward Earned";
"notification_evidence_timeout_reward_body" = "You earned a reward for task \"%@\" due to evidence timeout.";
```

**Step 4: Add Japanese iOS strings**

In `peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings`, add at the end:

```
"notification_evidence_timeout_title" = "エビデンス期限切れ";
"notification_evidence_timeout_body" = "タスク「%@」のエビデンス提出期限が過ぎました。ポイントが消費されました。";
"notification_evidence_timeout_reward_title" = "報酬獲得";
"notification_evidence_timeout_reward_body" = "タスク「%@」のエビデンス期限切れにより報酬を獲得しました。";
```

**Step 5: Commit**

```bash
git add peppercheck_flutter/android/app/src/main/res/values/strings.xml \
        peppercheck_flutter/android/app/src/main/res/values-ja/strings.xml \
        peppercheck_flutter/ios/Runner/en.lproj/Localizable.strings \
        peppercheck_flutter/ios/Runner/ja.lproj/Localizable.strings
git commit -m "feat: add evidence timeout notification templates to platform resources"
```

---

### Task 2: Add Dart-side notification i18n strings and regenerate slang

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`
- Auto-generated: `peppercheck_flutter/lib/gen/slang/strings.g.dart`, `strings_ja.g.dart`

**Step 1: Add notification section to ja.i18n.json**

Add a `"notification"` key at the top level of `peppercheck_flutter/assets/i18n/ja.i18n.json` (after the last entry, before the closing `}`):

```json
  "notification": {
    "evidence_timeout_title": "エビデンス期限切れ",
    "evidence_timeout_body": "タスク「${taskTitle}」のエビデンス提出期限が過ぎました。ポイントが消費されました。",
    "evidence_timeout_reward_title": "報酬獲得",
    "evidence_timeout_reward_body": "タスク「${taskTitle}」のエビデンス期限切れにより報酬を獲得しました。",
    "request_matched_title": "マッチング成立！",
    "request_matched_body": "あなたのタスク「${taskTitle}」のレフリーが見つかりました。",
    "referee_assigned_title": "新しい担当タスク",
    "referee_assigned_body": "タスク「${taskTitle}」の担当レフリーに選ばれました。",
    "request_accepted_title": "リクエスト承認",
    "request_accepted_body": "リクエストが承認されました。",
    "evidence_submitted_title": "エビデンス提出",
    "evidence_submitted_body": "${taskTitle}さんが新しいエビデンスを提出しました。",
    "evidence_updated_title": "エビデンス更新",
    "evidence_updated_body": "${taskTitle}さんがエビデンスを更新しました。",
    "fallback_title": "お知らせ",
    "fallback_body": "新しい通知があります。"
  }
```

**Step 2: Regenerate slang code**

Run from `peppercheck_flutter/`:

```bash
cd peppercheck_flutter && dart run slang
```

Expected: Generated files updated in `lib/gen/slang/`.

**Step 3: Verify generated code compiles**

```bash
cd peppercheck_flutter && dart analyze lib/gen/slang/
```

Expected: No errors.

**Step 4: Commit**

```bash
git add peppercheck_flutter/assets/i18n/ja.i18n.json \
        peppercheck_flutter/lib/gen/slang/
git commit -m "feat: add notification i18n strings for foreground display"
```

---

### Task 3: Add flutter_local_notifications dependency

**Files:**
- Modify: `peppercheck_flutter/pubspec.yaml`
- Modify: `peppercheck_flutter/android/app/src/main/AndroidManifest.xml`

**Step 1: Add dependency to pubspec.yaml**

In `peppercheck_flutter/pubspec.yaml`, add in the dependencies section (after `firebase_messaging: ^16.1.0`):

```yaml
  flutter_local_notifications:
```

No version constraint — `flutter pub get` will resolve to the latest compatible version.

**Step 2: Run flutter pub get**

```bash
cd peppercheck_flutter && flutter pub get
```

Expected: Dependencies resolved successfully.

**Step 3: Add notification icon metadata to AndroidManifest.xml**

In `peppercheck_flutter/android/app/src/main/AndroidManifest.xml`, add inside `<application>` tag (after the `flutterEmbedding` meta-data):

```xml
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/ic_launcher" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />
```

**Step 4: Commit**

```bash
git add peppercheck_flutter/pubspec.yaml \
        peppercheck_flutter/pubspec.lock \
        peppercheck_flutter/android/app/src/main/AndroidManifest.xml
git commit -m "feat: add flutter_local_notifications dependency and Android notification config"
```

---

### Task 4: Extend router to support `/task_detail/:taskId`

**Files:**
- Modify: `peppercheck_flutter/lib/app/routing/app_router.dart`
- Modify: `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart`
- Modify: `peppercheck_flutter/lib/features/home/presentation/widgets/task_card.dart`

**Step 1: Update TaskDetailScreen constructor**

Modify `peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart`:

Replace the current class with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';

import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_detail_info_section.dart';
import 'package:peppercheck_flutter/features/task/presentation/widgets/task_detail/task_referees_section.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/widgets/evidence_submission_section.dart';
import 'package:peppercheck_flutter/features/judgement/presentation/widgets/judgement_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peppercheck_flutter/features/task/presentation/providers/task_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  final Task? initialTask;

  const TaskDetailScreen({super.key, required this.taskId, this.initialTask});

  static const route = '/task_detail';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTask = ref.watch(taskProvider(taskId));

    // Use latest data if available, then initialTask, then show loading
    final displayTask = asyncTask.asData?.value ?? initialTask;

    if (displayTask == null) {
      return AppBackground(
        child: AppScaffold.scrollable(
          title: t.task.detail.title,
          currentIndex: -1,
          slivers: [
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    return AppBackground(
      child: AppScaffold.scrollable(
        title: t.task.detail.title,
        currentIndex: -1,
        onRefresh: () async {
          return ref.refresh(taskProvider(taskId).future);
        },
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskDetailInfoSection(task: displayTask),
                const SizedBox(height: AppSizes.sectionGap),
                TaskRefereesSection(task: displayTask),
                const SizedBox(height: AppSizes.sectionGap),
                if (_shouldShowEvidenceSection(displayTask)) ...[
                  EvidenceSubmissionSection(task: displayTask),
                  const SizedBox(height: AppSizes.sectionGap),
                ],
                JudgementSection(task: displayTask),
                const SizedBox(height: AppSizes.sectionGap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowEvidenceSection(Task task) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || task.taskerId != userId) {
      if (task.evidence != null) return true;
      return false;
    }

    if (task.evidence != null) return true;

    final hasEvidenceTimeout = task.refereeRequests.any(
      (req) => req.judgement?.status == 'evidence_timeout',
    );
    if (hasEvidenceTimeout) return true;

    final hasAcceptedRequest = task.refereeRequests.any(
      (req) => req.status == 'accepted',
    );
    return hasAcceptedRequest;
  }
}
```

Key changes:
- `task` field → `taskId` (required) + `initialTask` (optional, nullable)
- When `displayTask` is null (no initial task, still loading): show loading spinner
- When available: same behavior as before

**Step 2: Update router**

Modify `peppercheck_flutter/lib/app/routing/app_router.dart`, change the task_detail route from:

```dart
      GoRoute(
        path: '/task_detail',
        builder: (context, state) {
          final task = state.extra as Task;
          return TaskDetailScreen(task: task);
        },
      ),
```

to:

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

**Step 3: Update home screen navigation**

In `peppercheck_flutter/lib/features/home/presentation/widgets/task_card.dart`, change line 36:

From:
```dart
        onTap: onTap ?? () => context.push('/task_detail', extra: task),
```

To:
```dart
        onTap: onTap ?? () => context.push('/task_detail/${task.id}', extra: task),
```

**Step 4: Search for any other navigation to task_detail and update**

Run: `grep -rn "task_detail" peppercheck_flutter/lib/` to verify no other navigations need updating.

**Step 5: Verify compilation**

```bash
cd peppercheck_flutter && flutter analyze
```

Expected: No errors.

**Step 6: Commit**

```bash
git add peppercheck_flutter/lib/app/routing/app_router.dart \
        peppercheck_flutter/lib/features/task/presentation/task_detail_screen.dart \
        peppercheck_flutter/lib/features/home/presentation/widgets/task_card.dart
git commit -m "feat: extend router to support task_detail/:taskId for notification navigation"
```

---

### Task 5: Create notification text resolver

**Files:**
- Create: `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`

This utility resolves FCM `titleLocKey`/`bodyLocKey` to Dart-localized strings for foreground notification display.

**Step 1: Create the resolver**

Create `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`:

```dart
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

/// Resolves FCM title_loc_key / body_loc_key to localized Dart strings.
///
/// FCM sends notification messages with loc_keys that the platform resolves
/// for background/terminated notifications (from strings.xml / Localizable.strings).
/// For foreground notifications, we need to resolve them in Dart.
///
/// The loc_key format from the backend is: `notification_<type>_title` / `notification_<type>_body`.
/// The slang i18n keys are: `t.notification.<type>_title` / `t.notification.<type>_body`.
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
```

**Note on generated code:** The exact slang getter signatures (e.g. whether `evidence_timeout_body` takes a named `taskTitle` parameter or uses string interpolation) depend on how slang parses the `${taskTitle}` placeholder in the JSON. After slang code generation in Task 2, verify the generated API and adjust the resolver calls if needed.

**Step 2: Verify compilation**

```bash
cd peppercheck_flutter && dart analyze lib/features/notification/application/notification_text_resolver.dart
```

Expected: No errors (may need adjustment after seeing generated slang code).

**Step 3: Commit**

```bash
git add peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart
git commit -m "feat: add notification text resolver for foreground FCM messages"
```

---

### Task 6: Implement FCM handlers and flutter_local_notifications

**Files:**
- Modify: `peppercheck_flutter/lib/features/notification/application/fcm_service.dart`

This is the main task. It adds:
- `flutter_local_notifications` initialization
- Foreground notification display via `onMessage`
- Notification tap handling via `onMessageOpenedApp`, `getInitialMessage`, `onDidReceiveNotificationResponse`

**Step 1: Rewrite fcm_service.dart**

Replace the full content of `peppercheck_flutter/lib/features/notification/application/fcm_service.dart` with:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/app/routing/app_router.dart';
import 'package:peppercheck_flutter/features/notification/application/notification_text_resolver.dart';
import 'package:peppercheck_flutter/features/notification/data/notification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fcm_service.g.dart';

/// Android notification channel for high-importance notifications.
const _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

@Riverpod(keepAlive: true)
FcmService fcmService(Ref ref) {
  return FcmService(ref);
}

class FcmService {
  FcmService(this.ref);
  final Ref ref;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  int _notificationId = 0;

  Future<void> initialize() async {
    // 1. Request Permission
    final settings = await FirebaseMessaging.instance.requestPermission();
    debugPrint('[FCM] AuthorizationStatus: ${settings.authorizationStatus}');
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    // 2. Initialize flutter_local_notifications
    await _initLocalNotifications();

    // 3. Upload Token on start
    await _upsertCurrentToken();

    // 4. Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      ref.read(notificationRepositoryProvider).upsertToken(newToken);
    });

    // 5. Listen to Auth State Changes (Retry upsert on login)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        debugPrint('[FCM] User signed in, retrying token upsert');
        _upsertCurrentToken();
      }
    });

    // 6. Foreground Message Handling
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 7. Background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 8. Terminated notification tap (check on startup)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  /// Handle foreground FCM messages: show a local notification.
  void _handleForegroundMessage(RemoteMessage message) {
    final logger = ref.read(loggerProvider);
    logger.d('[FCM] Foreground message received: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Resolve localized text from loc_keys
    final resolved = resolveNotificationText(
      titleLocKey: notification.titleLocKey,
      bodyLocKey: notification.bodyLocKey,
      locArgs: notification.titleLocArgs,
    );

    // Encode message.data as payload for tap handling
    final payload = jsonEncode(message.data);

    _localNotifications.show(
      _notificationId++,
      resolved.title,
      resolved.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Handle notification tap from background/terminated state.
  void _handleNotificationTap(RemoteMessage message) {
    final logger = ref.read(loggerProvider);
    logger.d('[FCM] Notification tapped: ${message.data}');
    _navigateFromData(message.data);
  }

  /// Handle local notification tap (foreground).
  void _onLocalNotificationTap(NotificationResponse response) {
    final logger = ref.read(loggerProvider);
    logger.d('[FCM] Local notification tapped: ${response.payload}');

    if (response.payload == null || response.payload!.isEmpty) return;

    try {
      final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
      _navigateFromData(data);
    } catch (e) {
      debugPrint('[FCM] Failed to parse notification payload: $e');
    }
  }

  /// Navigate to the appropriate screen based on notification data.
  void _navigateFromData(Map<String, dynamic> data) {
    final taskId = data['task_id'] as String?;
    if (taskId == null) {
      debugPrint('[FCM] No task_id in notification data, ignoring');
      return;
    }

    final router = ref.read(routerProvider);
    router.push('/task_detail/$taskId');
  }

  Future<void> _upsertCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('[FCM] Token retrieved: $token');
    if (token != null) {
      await ref.read(notificationRepositoryProvider).upsertToken(token);
    } else {
      debugPrint('[FCM] Token is null');
    }
  }
}
```

**Step 2: Regenerate Riverpod code**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

Expected: `fcm_service.g.dart` regenerated successfully.

**Step 3: Verify compilation**

```bash
cd peppercheck_flutter && flutter analyze
```

Expected: No errors.

**Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/notification/application/fcm_service.dart \
        peppercheck_flutter/lib/features/notification/application/fcm_service.g.dart
git commit -m "feat: implement FCM handlers and foreground notification display"
```

---

### Task 7: Build verification

**Step 1: Run existing tests**

```bash
cd peppercheck_flutter && flutter test
```

Expected: All existing tests pass.

**Step 2: Full build check**

```bash
cd peppercheck_flutter && flutter build apk --debug
```

Expected: Build succeeds.

**Step 3: Commit any fixes if needed**

If any issues were found, fix and commit:

```bash
git add -A
git commit -m "fix: address issues found during build verification"
```

---

### Task 8: Push and create PR

**Step 1: Review the full diff**

```bash
git diff main...HEAD --stat
```

**Step 2: Push and create PR**

```bash
git push -u origin feat/evidence-timeout-notification
```

Create PR with title: `feat: add evidence timeout notification templates and FCM handler (#72)`

Summary should reference:
- Platform localization strings for 2 new notification types (evidence timeout + reward)
- Dart-side i18n for foreground notification text resolution
- `flutter_local_notifications` for foreground notification display
- FCM tap handlers for all app states (foreground, background, terminated)
- Router extension for task ID-based navigation
- Generic handler that works for all notification types with `task_id`
