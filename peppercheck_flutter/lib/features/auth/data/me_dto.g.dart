// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MeResponse _$MeResponseFromJson(Map<String, dynamic> json) => _MeResponse(
  user: MeUser.fromJson(json['user'] as Map<String, dynamic>),
  identity: MeIdentity.fromJson(json['identity'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MeResponseToJson(_MeResponse instance) =>
    <String, dynamic>{'user': instance.user, 'identity': instance.identity};

_MeUser _$MeUserFromJson(Map<String, dynamic> json) => _MeUser(
  id: json['id'] as String,
  status: json['status'] as String,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$MeUserToJson(_MeUser instance) => <String, dynamic>{
  'id': instance.id,
  'status': instance.status,
  'createdAt': instance.createdAt,
};

_MeIdentity _$MeIdentityFromJson(Map<String, dynamic> json) =>
    _MeIdentity(issuer: json['issuer'] as String);

Map<String, dynamic> _$MeIdentityToJson(_MeIdentity instance) =>
    <String, dynamic>{'issuer': instance.issuer};
