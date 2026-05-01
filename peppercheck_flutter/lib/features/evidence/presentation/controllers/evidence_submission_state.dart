import 'package:freezed_annotation/freezed_annotation.dart';

part 'evidence_submission_state.freezed.dart';

@freezed
sealed class EvidenceSubmissionState with _$EvidenceSubmissionState {
  const EvidenceSubmissionState._();

  const factory EvidenceSubmissionState.idle() = _Idle;
  const factory EvidenceSubmissionState.preparing({
    required int current,
    required int total,
  }) = _Preparing;
  const factory EvidenceSubmissionState.uploading({
    required int current,
    required int total,
  }) = _Uploading;

  bool get isLoading => switch (this) {
    _Idle() => false,
    _Preparing() || _Uploading() => true,
  };

  bool get isPreparing => this is _Preparing;
  bool get isUploading => this is _Uploading;

  ({int current, int total})? get progress => switch (this) {
    _Preparing(:final current, :final total) ||
    _Uploading(
      :final current,
      :final total,
    ) => (current: current, total: total),
    _Idle() => null,
  };
}
