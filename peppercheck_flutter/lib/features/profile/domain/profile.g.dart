// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Profile _$ProfileFromJson(Map<String, dynamic> json) => _Profile(
  id: json['id'] as String,
  username: json['username'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  createdAt: json['created_at'] as String?,
  stripeConnectAccountId: json['stripe_connect_account_id'] as String?,
  updatedAt: json['updated_at'] as String?,
  timezone: json['timezone'] as String?,
);

Map<String, dynamic> _$ProfileToJson(_Profile instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'avatar_url': instance.avatarUrl,
  'created_at': instance.createdAt,
  'stripe_connect_account_id': instance.stripeConnectAccountId,
  'updated_at': instance.updatedAt,
  'timezone': instance.timezone,
};
