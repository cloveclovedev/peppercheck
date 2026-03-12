// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_obligation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefereeObligation _$RefereeObligationFromJson(Map<String, dynamic> json) =>
    _RefereeObligation(
      id: json['id'] as String,
      status: json['status'] as String,
      sourceRequestId: json['source_request_id'] as String,
      fulfillRequestId: json['fulfill_request_id'] as String?,
      createdAt: json['created_at'] as String,
      fulfilledAt: json['fulfilled_at'] as String?,
    );

Map<String, dynamic> _$RefereeObligationToJson(_RefereeObligation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'source_request_id': instance.sourceRequestId,
      'fulfill_request_id': instance.fulfillRequestId,
      'created_at': instance.createdAt,
      'fulfilled_at': instance.fulfilledAt,
    };
