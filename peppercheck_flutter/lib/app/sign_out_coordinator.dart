import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';
import 'package:peppercheck_flutter/features/notification/application/fcm_service.dart';
import 'package:peppercheck_flutter/features/notification/data/notification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sign_out_coordinator.g.dart';

/// Composes sign-out across features so ordering is owned in one place
/// instead of by a cross-dependency between `features/notification` and
/// `features/auth`: the FCM token is deregistered while the Firebase bearer
/// is still valid, then Firebase itself is signed out. Call sites use this
/// instead of `AuthRepository.signOut()` directly.
class SignOutCoordinator {
  SignOutCoordinator({
    required NotificationRepository notificationRepository,
    required AuthRepository authRepository,
    required Logger logger,
    Future<String?> Function()? getToken,
    Duration deregisterTimeout = const Duration(seconds: 3),
    bool Function()? isSignedIn,
    Future<void> Function(String token)? reRegisterToken,
  }) : _notificationRepository = notificationRepository,
       _authRepository = authRepository,
       _logger = logger,
       _getToken = getToken,
       _deregisterTimeout = deregisterTimeout,
       _isSignedIn = isSignedIn,
       _reRegisterToken = reRegisterToken;

  final NotificationRepository _notificationRepository;
  final AuthRepository _authRepository;
  final Logger _logger;

  /// Injectable so tests can drive [signOut] without touching the real
  /// Firebase Messaging plugin; resolved lazily against
  /// `FirebaseMessaging.instance.getToken` so construction never touches it.
  final Future<String?> Function()? _getToken;

  /// Injectable so tests can exercise the timeout path quickly instead of
  /// waiting out the real 3-second bound.
  final Duration _deregisterTimeout;

  /// Reports whether Firebase still considers the user signed in *after*
  /// [AuthRepository.signOut] returns. Needed because that method never
  /// throws — each leg (Google, Firebase) is guarded independently — so a
  /// native Firebase sign-out failure is otherwise silent.
  final bool Function()? _isSignedIn;

  /// Re-registers the current token with the Go API; wired to
  /// `FcmService.registerToken` at composition so this class doesn't
  /// duplicate device-type detection.
  final Future<void> Function(String token)? _reRegisterToken;

  /// Brackets the whole flow — not just the deregister call — with
  /// [NotificationRepository.beginSignOut]/[endSignOut]. A token-refresh
  /// event can still fire `registerToken` after the deregister is queued
  /// but before Firebase sign-out actually completes (the signed-in check
  /// stays true until then); the repository drops such calls while this
  /// flag is set instead of letting them re-create the token binding sign-
  /// out just removed.
  ///
  /// If Firebase sign-out silently failed (still signed in once the flag
  /// clears), the deregister above just removed a still-valid account's
  /// token with no auth-state transition to naturally re-sync it — restore
  /// it best-effort rather than leave that account without notifications
  /// until an unrelated token refresh happens to fire.
  Future<void> signOut() async {
    _notificationRepository.beginSignOut();
    var restoreNeeded = false;
    try {
      await _deregisterFcmToken();
      await _authRepository.signOut();
      restoreNeeded = _isSignedIn?.call() ?? false;
    } finally {
      _notificationRepository.endSignOut();
    }
    if (restoreNeeded) {
      await _restoreTokenAfterFailedSignOut();
    }
  }

  Future<void> _restoreTokenAfterFailedSignOut() async {
    final reRegister = _reRegisterToken;
    if (reRegister == null) return;
    try {
      final getToken = _getToken ?? FirebaseMessaging.instance.getToken;
      final token = await getToken();
      if (token == null) return;
      await reRegister(token);
    } catch (e, st) {
      _logger.w(
        'Failed to restore FCM token after a failed sign-out',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Best-effort and bounded: a failed or slow FCM delete is logged and must
  /// not block Firebase sign-out — an offline user should not be stuck on
  /// the authenticated screen waiting for this network call to time out on
  /// its own.
  ///
  /// `Future.timeout` does not cancel the underlying work, so the unbounded
  /// call keeps running after we give up on it. If we let it reach the
  /// network after that point, it could delete a *different* signed-in
  /// user's token — e.g. this device's shared FCM token gets rebound to a
  /// second account that signs in while the first account's slow deregister
  /// is still in flight, or fire with no bearer at all once Firebase has
  /// signed out. `isCancelled` is checked both before handing off to the
  /// repository *and* passed through to it, since the repository's own
  /// serialization queue (an earlier `registerToken` occupying it) can defer
  /// the actual network call past this deadline even after the first check
  /// passes — see [NotificationRepository.deregisterToken].
  Future<void> _deregisterFcmToken() async {
    var cancelled = false;
    final unbounded = _deregisterFcmTokenUnbounded(
      isCancelled: () => cancelled,
    );
    unawaited(
      unbounded.catchError((Object e, StackTrace st) {
        _logger.w('FCM token deregistration failed', error: e, stackTrace: st);
      }),
    );
    try {
      await unbounded.timeout(_deregisterTimeout);
    } on TimeoutException {
      cancelled = true;
      _logger.w('FCM token deregistration timed out after $_deregisterTimeout');
    } catch (_) {
      // Already logged by the detached handler above.
    }
  }

  Future<void> _deregisterFcmTokenUnbounded({
    required bool Function() isCancelled,
  }) async {
    final getToken = _getToken ?? FirebaseMessaging.instance.getToken;
    final token = await getToken();
    if (token == null) return;
    if (isCancelled()) return;
    await _notificationRepository.deregisterToken(
      token,
      isCancelled: isCancelled,
    );
  }
}

@Riverpod(keepAlive: true)
SignOutCoordinator signOutCoordinator(Ref ref) {
  return SignOutCoordinator(
    notificationRepository: ref.watch(notificationRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(loggerProvider),
    isSignedIn: () => ref.read(isFirebaseAuthenticatedProvider),
    reRegisterToken: ref.read(fcmServiceProvider).registerToken,
  );
}
