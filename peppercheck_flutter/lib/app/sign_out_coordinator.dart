import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';
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
  }) : _notificationRepository = notificationRepository,
       _authRepository = authRepository,
       _logger = logger,
       _getToken = getToken;

  final NotificationRepository _notificationRepository;
  final AuthRepository _authRepository;
  final Logger _logger;

  /// Injectable so tests can drive [signOut] without touching the real
  /// Firebase Messaging plugin; resolved lazily against
  /// `FirebaseMessaging.instance.getToken` so construction never touches it.
  final Future<String?> Function()? _getToken;

  Future<void> signOut() async {
    await _deregisterFcmToken();
    await _authRepository.signOut();
  }

  /// Best-effort: a failed FCM delete is logged and must not block Firebase
  /// sign-out.
  Future<void> _deregisterFcmToken() async {
    try {
      final getToken = _getToken ?? FirebaseMessaging.instance.getToken;
      final token = await getToken();
      if (token == null) return;
      await _notificationRepository.deregisterToken(token);
    } catch (e, st) {
      _logger.w('FCM token deregistration failed', error: e, stackTrace: st);
    }
  }
}

@Riverpod(keepAlive: true)
SignOutCoordinator signOutCoordinator(Ref ref) {
  return SignOutCoordinator(
    notificationRepository: ref.watch(notificationRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(loggerProvider),
  );
}
