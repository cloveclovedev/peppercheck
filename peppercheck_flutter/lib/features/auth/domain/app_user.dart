import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// The app-level current user, provider-neutral. This is the ONLY user type
/// features read; it exposes the PepperCheck-internal UUID (Phase 5 wires
/// RevenueCat identify to [internalUserId]). It carries no profile — profile
/// lands in Phase 3. Domain type: it imports no DTO and no Firebase type.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String internalUserId,
    required String issuer,
    required String status,
    required DateTime createdAt,
  }) = _AppUser;
}
