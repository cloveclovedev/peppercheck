import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';

part 'notification_repository.g.dart';

/// Syncs the device's push token with the Go API. The route is
/// `/api/v1/me/device-push-tokens` (a legacy "fcm-tokens" name lingers in
/// planning docs; the backend handler lives in `internal/notification`).
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  static const _path = '/api/v1/me/device-push-tokens';

  Future<void> registerToken(String token, String deviceType) {
    return _api.putJson(
      _path,
      body: {'token': token, 'deviceType': deviceType},
    );
  }

  Future<void> deregisterToken(String token) {
    return _api.deleteJson(_path, body: {'token': token});
  }
}

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
}
