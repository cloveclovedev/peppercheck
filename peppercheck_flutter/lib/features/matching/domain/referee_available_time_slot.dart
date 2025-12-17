import 'package:freezed_annotation/freezed_annotation.dart';

part 'referee_available_time_slot.freezed.dart';
part 'referee_available_time_slot.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class RefereeAvailableTimeSlot with _$RefereeAvailableTimeSlot {
  const factory RefereeAvailableTimeSlot({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required int dow,
    @JsonKey(name: 'start_min') required int startMin,
    @JsonKey(name: 'end_min') required int endMin,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _RefereeAvailableTimeSlot;

  factory RefereeAvailableTimeSlot.fromJson(Map<String, dynamic> json) =>
      _$RefereeAvailableTimeSlotFromJson(json);
}
