import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/referee_available_time_slot.dart';

part 'referee_time_slot_dto.freezed.dart';
part 'referee_time_slot_dto.g.dart';

/// Mirrors an availability time slot of the wire contract (§7.1):
/// `{ id, dow, startMin, endMin, isActive }`. The owner is implied by the
/// bearer, so there is no user id on the wire.
@freezed
abstract class RefereeTimeSlotDto with _$RefereeTimeSlotDto {
  const RefereeTimeSlotDto._();

  const factory RefereeTimeSlotDto({
    required String id,
    required int dow,
    required int startMin,
    required int endMin,
    required bool isActive,
  }) = _RefereeTimeSlotDto;

  factory RefereeTimeSlotDto.fromJson(Map<String, dynamic> json) =>
      _$RefereeTimeSlotDtoFromJson(json);

  RefereeAvailableTimeSlot toDomain() => RefereeAvailableTimeSlot(
    id: id,
    dow: dow,
    startMin: startMin,
    endMin: endMin,
    isActive: isActive,
  );
}
