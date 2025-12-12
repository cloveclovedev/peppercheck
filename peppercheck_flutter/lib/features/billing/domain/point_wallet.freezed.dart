// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'point_wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PointWallet {

 int get balance;
/// Create a copy of PointWallet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PointWalletCopyWith<PointWallet> get copyWith => _$PointWalletCopyWithImpl<PointWallet>(this as PointWallet, _$identity);

  /// Serializes this PointWallet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PointWallet&&(identical(other.balance, balance) || other.balance == balance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance);

@override
String toString() {
  return 'PointWallet(balance: $balance)';
}


}

/// @nodoc
abstract mixin class $PointWalletCopyWith<$Res>  {
  factory $PointWalletCopyWith(PointWallet value, $Res Function(PointWallet) _then) = _$PointWalletCopyWithImpl;
@useResult
$Res call({
 int balance
});




}
/// @nodoc
class _$PointWalletCopyWithImpl<$Res>
    implements $PointWalletCopyWith<$Res> {
  _$PointWalletCopyWithImpl(this._self, this._then);

  final PointWallet _self;
  final $Res Function(PointWallet) _then;

/// Create a copy of PointWallet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = null,}) {
  return _then(_self.copyWith(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PointWallet].
extension PointWalletPatterns on PointWallet {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PointWallet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PointWallet() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PointWallet value)  $default,){
final _that = this;
switch (_that) {
case _PointWallet():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PointWallet value)?  $default,){
final _that = this;
switch (_that) {
case _PointWallet() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int balance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PointWallet() when $default != null:
return $default(_that.balance);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int balance)  $default,) {final _that = this;
switch (_that) {
case _PointWallet():
return $default(_that.balance);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int balance)?  $default,) {final _that = this;
switch (_that) {
case _PointWallet() when $default != null:
return $default(_that.balance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PointWallet implements PointWallet {
  const _PointWallet({this.balance = 0});
  factory _PointWallet.fromJson(Map<String, dynamic> json) => _$PointWalletFromJson(json);

@override@JsonKey() final  int balance;

/// Create a copy of PointWallet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PointWalletCopyWith<_PointWallet> get copyWith => __$PointWalletCopyWithImpl<_PointWallet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PointWalletToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PointWallet&&(identical(other.balance, balance) || other.balance == balance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance);

@override
String toString() {
  return 'PointWallet(balance: $balance)';
}


}

/// @nodoc
abstract mixin class _$PointWalletCopyWith<$Res> implements $PointWalletCopyWith<$Res> {
  factory _$PointWalletCopyWith(_PointWallet value, $Res Function(_PointWallet) _then) = __$PointWalletCopyWithImpl;
@override @useResult
$Res call({
 int balance
});




}
/// @nodoc
class __$PointWalletCopyWithImpl<$Res>
    implements _$PointWalletCopyWith<$Res> {
  __$PointWalletCopyWithImpl(this._self, this._then);

  final _PointWallet _self;
  final $Res Function(_PointWallet) _then;

/// Create a copy of PointWallet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = null,}) {
  return _then(_PointWallet(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
