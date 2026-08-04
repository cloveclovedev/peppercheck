import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/app/routing/app_router.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/notification/application/notification_text_resolver.dart';
import 'package:peppercheck_flutter/features/notification/data/notification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  final service = FcmService(ref);
  // Retry the token upsert whenever Firebase auth state flips to signed-in.
  // Registered here (during this provider's own build) because `ref.listen`
  // is only safe within a provider's build scope, not from an async method
  // called later.
  ref.listen(authStateChangesProvider, (previous, next) {
    if (next.value != null) {
      service.onSignedIn();
    }
  });
  return service;
}

class FcmService {
  FcmService(this.ref, {Future<String?> Function()? getToken})
    : _getToken = getToken;

  final Ref ref;

  /// Injectable so tests can drive [onSignedIn] without touching the real
  /// Firebase Messaging plugin. Resolved lazily against
  /// `FirebaseMessaging.instance.getToken` in [_upsertCurrentToken] so
  /// construction never touches the Firebase Messaging plugin when a fake is
  /// supplied.
  final Future<String?> Function()? _getToken;

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

    // 3. Upload Token on start. Isolated in its own try/catch: a transient
    // API failure here must not abort the listener registrations below,
    // or notification handling stays disabled for the rest of the process.
    try {
      await _upsertCurrentToken();
    } catch (e, st) {
      ref
          .read(loggerProvider)
          .w(
            '[FCM] Token registration failed at startup',
            error: e,
            stackTrace: st,
          );
    }

    // 4. Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(registerToken);

    // 5. Auth-state-triggered retry is registered once, at provider-build
    // time, in `fcmServiceProvider` above — see `onSignedIn`.

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
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
          AndroidFlutterLocalNotificationsPlugin
        >()
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

  /// Called when Firebase auth state flips to signed-in. Retries the token
  /// upsert (idempotent).
  Future<void> onSignedIn() async {
    debugPrint('[FCM] User signed in, retrying token upsert');
    await _upsertCurrentToken();
  }

  Future<void> _upsertCurrentToken() async {
    final getToken = _getToken ?? FirebaseMessaging.instance.getToken;
    final token = await getToken();
    if (token == null) {
      debugPrint('[FCM] Token is null');
      return;
    }
    await registerToken(token);
  }

  /// Registers [token] with the Go API, gated on the current signed-in
  /// state — a signed-out call is a no-op rather than an unauthenticated
  /// request. Shared by app start, `onTokenRefresh`, and [onSignedIn].
  Future<void> registerToken(String token) async {
    if (!ref.read(isFirebaseAuthenticatedProvider)) {
      debugPrint('[FCM] Skipping token registration; signed out');
      return;
    }
    debugPrint('[FCM] Registering token (${_maskToken(token)})');
    await ref
        .read(notificationRepositoryProvider)
        .registerToken(token, _deviceType());
  }

  String _deviceType() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Never log the full FCM token — only enough to correlate log lines.
  String _maskToken(String token) {
    if (token.length <= 8) return '*' * token.length;
    return '${token.substring(0, 4)}…${token.substring(token.length - 4)}';
  }
}
