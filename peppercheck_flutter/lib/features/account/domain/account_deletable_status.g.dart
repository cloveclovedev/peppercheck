// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletable_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountDeletableStatus _$AccountDeletableStatusFromJson(
  Map<String, dynamic> json,
) => _AccountDeletableStatus(
  deletable: json['deletable'] as bool,
  reasons:
      (json['reasons'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$AccountDeletableStatusToJson(
  _AccountDeletableStatus instance,
) => <String, dynamic>{
  'deletable': instance.deletable,
  'reasons': instance.reasons,
};
