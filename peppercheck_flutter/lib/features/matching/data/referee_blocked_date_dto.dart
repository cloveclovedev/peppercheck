import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/referee_blocked_date.dart';

part 'referee_blocked_date_dto.freezed.dart';
part 'referee_blocked_date_dto.g.dart';

/// Mirrors a blocked date range of the wire contract (§7.1):
/// `{ id, startDate, endDate, reason? }`, where the dates are plain
/// `YYYY-MM-DD` calendar days rather than instants.
@freezed
abstract class RefereeBlockedDateDto with _$RefereeBlockedDateDto {
  const RefereeBlockedDateDto._();

  const factory RefereeBlockedDateDto({
    required String id,
    required String startDate,
    required String endDate,
    String? reason,
  }) = _RefereeBlockedDateDto;

  factory RefereeBlockedDateDto.fromJson(Map<String, dynamic> json) =>
      _$RefereeBlockedDateDtoFromJson(json);

  RefereeBlockedDate toDomain() => RefereeBlockedDate(
    id: id,
    startDate: DateTime.parse(startDate),
    endDate: DateTime.parse(endDate),
    reason: reason,
  );
}
