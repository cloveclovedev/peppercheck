import 'package:freezed_annotation/freezed_annotation.dart';

part 'referee_available_time_slot.freezed.dart';

/// A weekly window in which the referee accepts assignments. `dow` is the day
/// of week and the minute fields are offsets from midnight in the referee's
/// own timezone.
@freezed
abstract class RefereeAvailableTimeSlot with _$RefereeAvailableTimeSlot {
  const factory RefereeAvailableTimeSlot({
    required String id,
    required int dow,
    required int startMin,
    required int endMin,
    required bool isActive,
  }) = _RefereeAvailableTimeSlot;
}
