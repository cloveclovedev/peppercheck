import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_creation_request.freezed.dart';
part 'task_creation_request.g.dart';

@freezed
abstract class TaskCreationRequest with _$TaskCreationRequest {
  const factory TaskCreationRequest({
    @Default('') String title,
    @Default('') String description,
    @Default('') String criteria,
    DateTime? selectedDateTime,
    @Default('open') String taskStatus,
    @Default([]) List<String> selectedStrategies,
  }) = _TaskCreationRequest;

  factory TaskCreationRequest.fromJson(Map<String, dynamic> json) =>
      _$TaskCreationRequestFromJson(json);
}
