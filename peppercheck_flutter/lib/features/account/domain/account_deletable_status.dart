import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_deletable_status.freezed.dart';
part 'account_deletable_status.g.dart';

@freezed
abstract class AccountDeletableStatus with _$AccountDeletableStatus {
  const factory AccountDeletableStatus({
    required bool deletable,
    @Default([]) List<String> reasons,
  }) = _AccountDeletableStatus;

  factory AccountDeletableStatus.fromJson(Map<String, dynamic> json) =>
      _$AccountDeletableStatusFromJson(json);
}
