import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_repository.g.dart';

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  return NotificationRepository();
}

class NotificationRepository {
  /// Upserts the FCM token to the `public.user_fcm_tokens` table.
  ///
  /// Disabled until the notification feature migrates to the Go API
  /// (Phase 3). Token sync was keyed on the Supabase session, which no
  /// longer exists on the auth path after the Firebase identity switch.
  /// Re-enable when notifications move; do not silently no-op without this
  /// guard comment.
  Future<void> upsertToken(String token) async {
    return;
  }

  /// Removes the token on logout.
  ///
  /// Disabled for the same reason as [upsertToken] — see above.
  Future<void> deleteToken(String token) async {
    return;
  }
}
