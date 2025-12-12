import 'package:freezed_annotation/freezed_annotation.dart';

part 'point_wallet.freezed.dart';
part 'point_wallet.g.dart';

// ignore_for_file: invalid_annotation_target

@freezed
abstract class PointWallet with _$PointWallet {
  const factory PointWallet({@Default(0) int balance}) = _PointWallet;

  factory PointWallet.fromJson(Map<String, dynamic> json) =>
      _$PointWalletFromJson(json);
}
