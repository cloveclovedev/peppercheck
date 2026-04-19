// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payout_setup_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PayoutSetupStatus {

@JsonKey(name: 'charges_enabled') bool get chargesEnabled;@JsonKey(name: 'payouts_enabled') bool get payoutsEnabled; List<String> get currentlyDue; List<String> get pendingVerification;
/// Create a copy of PayoutSetupStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PayoutSetupStatusCopyWith<PayoutSetupStatus> get copyWith => _$PayoutSetupStatusCopyWithImpl<PayoutSetupStatus>(this as PayoutSetupStatus, _$identity);

  /// Serializes this PayoutSetupStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PayoutSetupStatus&&(identical(other.chargesEnabled, chargesEnabled) || other.chargesEnabled == chargesEnabled)&&(identical(other.payoutsEnabled, payoutsEnabled) || other.payoutsEnabled == payoutsEnabled)&&const DeepCollectionEquality().equals(other.currentlyDue, currentlyDue)&&const DeepCollectionEquality().equals(other.pendingVerification, pendingVerification));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chargesEnabled,payoutsEnabled,const DeepCollectionEquality().hash(currentlyDue),const DeepCollectionEquality().hash(pendingVerification));

@override
String toString() {
  return 'PayoutSetupStatus(chargesEnabled: $chargesEnabled, payoutsEnabled: $payoutsEnabled, currentlyDue: $currentlyDue, pendingVerification: $pendingVerification)';
}


}

/// @nodoc
abstract mixin class $PayoutSetupStatusCopyWith<$Res>  {
  factory $PayoutSetupStatusCopyWith(PayoutSetupStatus value, $Res Function(PayoutSetupStatus) _then) = _$PayoutSetupStatusCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'charges_enabled') bool chargesEnabled,@JsonKey(name: 'payouts_enabled') bool payoutsEnabled, List<String> currentlyDue, List<String> pendingVerification
});




}
/// @nodoc
class _$PayoutSetupStatusCopyWithImpl<$Res>
    implements $PayoutSetupStatusCopyWith<$Res> {
  _$PayoutSetupStatusCopyWithImpl(this._self, this._then);

  final PayoutSetupStatus _self;
  final $Res Function(PayoutSetupStatus) _then;

/// Create a copy of PayoutSetupStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chargesEnabled = null,Object? payoutsEnabled = null,Object? currentlyDue = null,Object? pendingVerification = null,}) {
  return _then(_self.copyWith(
chargesEnabled: null == chargesEnabled ? _self.chargesEnabled : chargesEnabled // ignore: cast_nullable_to_non_nullable
as bool,payoutsEnabled: null == payoutsEnabled ? _self.payoutsEnabled : payoutsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentlyDue: null == currentlyDue ? _self.currentlyDue : currentlyDue // ignore: cast_nullable_to_non_nullable
as List<String>,pendingVerification: null == pendingVerification ? _self.pendingVerification : pendingVerification // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PayoutSetupStatus].
extension PayoutSetupStatusPatterns on PayoutSetupStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PayoutSetupStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PayoutSetupStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PayoutSetupStatus value)  $default,){
final _that = this;
switch (_that) {
case _PayoutSetupStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PayoutSetupStatus value)?  $default,){
final _that = this;
switch (_that) {
case _PayoutSetupStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'charges_enabled')  bool chargesEnabled, @JsonKey(name: 'payouts_enabled')  bool payoutsEnabled,  List<String> currentlyDue,  List<String> pendingVerification)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PayoutSetupStatus() when $default != null:
return $default(_that.chargesEnabled,_that.payoutsEnabled,_that.currentlyDue,_that.pendingVerification);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'charges_enabled')  bool chargesEnabled, @JsonKey(name: 'payouts_enabled')  bool payoutsEnabled,  List<String> currentlyDue,  List<String> pendingVerification)  $default,) {final _that = this;
switch (_that) {
case _PayoutSetupStatus():
return $default(_that.chargesEnabled,_that.payoutsEnabled,_that.currentlyDue,_that.pendingVerification);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'charges_enabled')  bool chargesEnabled, @JsonKey(name: 'payouts_enabled')  bool payoutsEnabled,  List<String> currentlyDue,  List<String> pendingVerification)?  $default,) {final _that = this;
switch (_that) {
case _PayoutSetupStatus() when $default != null:
return $default(_that.chargesEnabled,_that.payoutsEnabled,_that.currentlyDue,_that.pendingVerification);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PayoutSetupStatus extends PayoutSetupStatus {
  const _PayoutSetupStatus({@JsonKey(name: 'charges_enabled') this.chargesEnabled = false, @JsonKey(name: 'payouts_enabled') this.payoutsEnabled = false, final  List<String> currentlyDue = const [], final  List<String> pendingVerification = const []}): _currentlyDue = currentlyDue,_pendingVerification = pendingVerification,super._();
  factory _PayoutSetupStatus.fromJson(Map<String, dynamic> json) => _$PayoutSetupStatusFromJson(json);

@override@JsonKey(name: 'charges_enabled') final  bool chargesEnabled;
@override@JsonKey(name: 'payouts_enabled') final  bool payoutsEnabled;
 final  List<String> _currentlyDue;
@override@JsonKey() List<String> get currentlyDue {
  if (_currentlyDue is EqualUnmodifiableListView) return _currentlyDue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_currentlyDue);
}

 final  List<String> _pendingVerification;
@override@JsonKey() List<String> get pendingVerification {
  if (_pendingVerification is EqualUnmodifiableListView) return _pendingVerification;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingVerification);
}


/// Create a copy of PayoutSetupStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PayoutSetupStatusCopyWith<_PayoutSetupStatus> get copyWith => __$PayoutSetupStatusCopyWithImpl<_PayoutSetupStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PayoutSetupStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PayoutSetupStatus&&(identical(other.chargesEnabled, chargesEnabled) || other.chargesEnabled == chargesEnabled)&&(identical(other.payoutsEnabled, payoutsEnabled) || other.payoutsEnabled == payoutsEnabled)&&const DeepCollectionEquality().equals(other._currentlyDue, _currentlyDue)&&const DeepCollectionEquality().equals(other._pendingVerification, _pendingVerification));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chargesEnabled,payoutsEnabled,const DeepCollectionEquality().hash(_currentlyDue),const DeepCollectionEquality().hash(_pendingVerification));

@override
String toString() {
  return 'PayoutSetupStatus(chargesEnabled: $chargesEnabled, payoutsEnabled: $payoutsEnabled, currentlyDue: $currentlyDue, pendingVerification: $pendingVerification)';
}


}

/// @nodoc
abstract mixin class _$PayoutSetupStatusCopyWith<$Res> implements $PayoutSetupStatusCopyWith<$Res> {
  factory _$PayoutSetupStatusCopyWith(_PayoutSetupStatus value, $Res Function(_PayoutSetupStatus) _then) = __$PayoutSetupStatusCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'charges_enabled') bool chargesEnabled,@JsonKey(name: 'payouts_enabled') bool payoutsEnabled, List<String> currentlyDue, List<String> pendingVerification
});




}
/// @nodoc
class __$PayoutSetupStatusCopyWithImpl<$Res>
    implements _$PayoutSetupStatusCopyWith<$Res> {
  __$PayoutSetupStatusCopyWithImpl(this._self, this._then);

  final _PayoutSetupStatus _self;
  final $Res Function(_PayoutSetupStatus) _then;

/// Create a copy of PayoutSetupStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chargesEnabled = null,Object? payoutsEnabled = null,Object? currentlyDue = null,Object? pendingVerification = null,}) {
  return _then(_PayoutSetupStatus(
chargesEnabled: null == chargesEnabled ? _self.chargesEnabled : chargesEnabled // ignore: cast_nullable_to_non_nullable
as bool,payoutsEnabled: null == payoutsEnabled ? _self.payoutsEnabled : payoutsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentlyDue: null == currentlyDue ? _self._currentlyDue : currentlyDue // ignore: cast_nullable_to_non_nullable
as List<String>,pendingVerification: null == pendingVerification ? _self._pendingVerification : pendingVerification // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
