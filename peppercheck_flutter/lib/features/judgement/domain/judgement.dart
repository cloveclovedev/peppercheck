import 'package:freezed_annotation/freezed_annotation.dart';

part 'judgement.freezed.dart';
part 'judgement.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class Judgement with _$Judgement {
  const factory Judgement({
    required String id,
    required String status,
    String? comment,
    @JsonKey(name: 'is_confirmed') @Default(false) bool isConfirmed,
    @JsonKey(name: 'reopen_count') @Default(0) int reopenCount,
    @JsonKey(name: 'can_reopen') @Default(false) bool canReopen,
    @JsonKey(name: 'is_evidence_timeout_confirmed')
    @Default(false)
    bool isEvidenceTimeoutConfirmed,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _Judgement;

  factory Judgement.fromJson(Map<String, dynamic> json) =>
      _$JudgementFromJson(json);
}
