import 'package:freezed_annotation/freezed_annotation.dart';

part 'trial_point_wallet.freezed.dart';
part 'trial_point_wallet.g.dart';

@freezed
abstract class TrialPointWallet with _$TrialPointWallet {
  const factory TrialPointWallet({
    @Default(0) int balance,
    @Default(0) int locked,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
  }) = _TrialPointWallet;

  factory TrialPointWallet.fromJson(Map<String, dynamic> json) =>
      _$TrialPointWalletFromJson(json);
}
