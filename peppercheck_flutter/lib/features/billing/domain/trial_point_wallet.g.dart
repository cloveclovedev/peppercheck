// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trial_point_wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrialPointWallet _$TrialPointWalletFromJson(Map<String, dynamic> json) =>
    _TrialPointWallet(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      locked: (json['locked'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$TrialPointWalletToJson(_TrialPointWallet instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'locked': instance.locked,
      'is_active': instance.isActive,
    };
