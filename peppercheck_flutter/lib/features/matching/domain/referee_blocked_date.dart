import 'package:freezed_annotation/freezed_annotation.dart';

part 'referee_blocked_date.freezed.dart';
part 'referee_blocked_date.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class RefereeBlockedDate with _$RefereeBlockedDate {
  const factory RefereeBlockedDate({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') required DateTime endDate,
    String? reason,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _RefereeBlockedDate;

  factory RefereeBlockedDate.fromJson(Map<String, dynamic> json) =>
      _$RefereeBlockedDateFromJson(json);
}
