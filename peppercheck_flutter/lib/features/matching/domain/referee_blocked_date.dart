import 'package:freezed_annotation/freezed_annotation.dart';

part 'referee_blocked_date.freezed.dart';

/// An inclusive range of calendar days on which the referee takes no
/// assignments.
@freezed
abstract class RefereeBlockedDate with _$RefereeBlockedDate {
  const factory RefereeBlockedDate({
    required String id,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) = _RefereeBlockedDate;
}
