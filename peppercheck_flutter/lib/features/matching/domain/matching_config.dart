import 'package:freezed_annotation/freezed_annotation.dart';

part 'matching_config.freezed.dart';

/// Server-owned matching deadlines and limits, served by
/// `GET /api/v1/matching/config`. The client never mirrors these as constants —
/// a stale copy would disagree with the server that enforces them.
@freezed
abstract class MatchingConfig with _$MatchingConfig {
  const factory MatchingConfig({
    required int openDeadlineHours,
    required int cancelDeadlineHours,
    required int rematchCutoffHours,
    required int maxRefereesPerTask,
    required int matchingPointCost,
  }) = _MatchingConfig;
}
