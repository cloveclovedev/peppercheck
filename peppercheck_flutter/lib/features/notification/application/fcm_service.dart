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
      settings: initSettings,
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

    // Resolve localized text from loc_keys.
    // Using titleLocArgs for both title and body because the backend
    // sends the same args (task title) for both via notify_event().
    final resolved = resolveNotificationText(
      titleLocKey: notification.titleLocKey,
      bodyLocKey: notification.bodyLocKey,
      locArgs: notification.titleLocArgs,
    );

    // Encode message.data as payload for tap handling
    final payload = jsonEncode(message.data);

    _localNotifications.show(
      id: _notificationId++,
      title: resolved.title,
      body: resolved.body,
      notificationDetails: NotificationDetails(
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
