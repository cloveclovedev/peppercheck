import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'notification_repository.g.dart';

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  return NotificationRepository(Supabase.instance.client);
}

class NotificationRepository {
  NotificationRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Upserts the FCM token to the `public.user_fcm_tokens` table.
  /// Needs to be called on app start and when token refreshes.
  Future<void> upsertToken(String token) async {
    final user = _supabase.auth.currentUser;
    debugPrint('[NotificationRepo] Current User: ${user?.id}');
    if (user == null) {
      debugPrint('[NotificationRepo] User is null, skipping upsert');
      return;
    }

    try {
      await _supabase.from('user_fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'device_type': Platform.isAndroid
            ? 'android'
            : Platform.isIOS
            ? 'ios'
            : 'web',
        'last_active_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      // Log error appropriately
      debugPrint('[NotificationRepo] Error upserting token: $e');
    }
  }

  /// Removes the token on logout
  Future<void> deleteToken(String token) async {
    try {
      await _supabase.from('user_fcm_tokens').delete().eq('token', token);
    } catch (e) {
      // Error deleting FCM token
    }
  }
}
