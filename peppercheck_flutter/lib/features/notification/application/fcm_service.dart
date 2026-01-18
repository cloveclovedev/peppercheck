import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/notification/data/notification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fcm_service.g.dart';

@Riverpod(keepAlive: true)
FcmService fcmService(Ref ref) {
  return FcmService(ref);
}

class FcmService {
  FcmService(this.ref);
  final Ref ref;

  Future<void> initialize() async {
    // 1. Request Permission
    final settings = await FirebaseMessaging.instance.requestPermission();
    debugPrint('[FCM] AuthorizationStatus: ${settings.authorizationStatus}');
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    // 2. Upload Token on start
    await _upsertCurrentToken();

    // 3. Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      ref.read(notificationRepositoryProvider).upsertToken(newToken);
    });

    // 4. Listen to Auth State Changes (Retry upsert on login)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        debugPrint('[FCM] User signed in, retrying token upsert');
        _upsertCurrentToken();
      }
    });

    // 5. Foreground Message Handling (Optional)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground messages if needed (e.g. show local notification)
      final logger = ref.read(loggerProvider);
      logger.d('Got a message whilst in the foreground!');
      logger.d('Message data: ${message.data}');

      if (message.notification != null) {
        logger.d(
          'Message also contained a notification: ${message.notification}',
        );
      }
    });
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
