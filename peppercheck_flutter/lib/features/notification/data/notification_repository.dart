import 'dart:async';

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

  /// Serializes register/deregister calls so they complete in invocation
  /// order regardless of individual network timing. Without this, a
  /// fire-and-forget startup registration that is still in flight when the
  /// user signs out can complete *after* the sign-out deregistration — the
  /// backend upserts on conflict (`internal/notification/store.go`), so a
  /// late PUT silently recreates the token binding the DELETE just removed,
  /// leaking notifications to a signed-out (or since-switched) account.
  Future<void> _queue = Future<void>.value();

  /// Set for the duration of [SignOutCoordinator.signOut] via
  /// [beginSignOut]/[endSignOut]. Ordering the queue alone is not enough: an
  /// FCM token-refresh event can fire `registerToken` *while* sign-out is in
  /// flight (the auth state doesn't flip to signed-out until Firebase sign-
  /// out itself completes), and that call would otherwise be queued right
  /// after the deregister and immediately recreate the binding it just
  /// removed. While this flag is set, `registerToken` is a silent no-op.
  bool _signOutInProgress = false;

  Future<void> _enqueue(Future<void> Function() op) {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    unawaited(
      previous
          .catchError((_) {}) // a prior failure must not block this op
          .then((_) => op())
          .then(completer.complete, onError: completer.completeError),
    );
    return completer.future;
  }

  Future<void> registerToken(String token, String deviceType) {
    if (_signOutInProgress) return Future<void>.value();
    return _enqueue(
      () =>
          _api.putJson(_path, body: {'token': token, 'deviceType': deviceType}),
    );
  }

  Future<void> deregisterToken(String token) {
    return _enqueue(() => _api.deleteJson(_path, body: {'token': token}));
  }

  /// Brackets [SignOutCoordinator.signOut] so no `registerToken` call
  /// invoked during sign-out (deregister through Firebase actually signing
  /// out) can slip in and undo it. Always pair with [endSignOut] in a
  /// `finally` block.
  void beginSignOut() => _signOutInProgress = true;

  void endSignOut() => _signOutInProgress = false;
}

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
}
