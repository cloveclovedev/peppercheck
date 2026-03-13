// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_deletable_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountDeletableStatus {

 bool get deletable; List<String> get reasons;
/// Create a copy of AccountDeletableStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountDeletableStatusCopyWith<AccountDeletableStatus> get copyWith => _$AccountDeletableStatusCopyWithImpl<AccountDeletableStatus>(this as AccountDeletableStatus, _$identity);

  /// Serializes this AccountDeletableStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountDeletableStatus&&(identical(other.deletable, deletable) || other.deletable == deletable)&&const DeepCollectionEquality().equals(other.reasons, reasons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deletable,const DeepCollectionEquality().hash(reasons));

@override
String toString() {
  return 'AccountDeletableStatus(deletable: $deletable, reasons: $reasons)';
}


}

/// @nodoc
abstract mixin class $AccountDeletableStatusCopyWith<$Res>  {
  factory $AccountDeletableStatusCopyWith(AccountDeletableStatus value, $Res Function(AccountDeletableStatus) _then) = _$AccountDeletableStatusCopyWithImpl;
@useResult
$Res call({
 bool deletable, List<String> reasons
});




}
/// @nodoc
class _$AccountDeletableStatusCopyWithImpl<$Res>
    implements $AccountDeletableStatusCopyWith<$Res> {
  _$AccountDeletableStatusCopyWithImpl(this._self, this._then);

  final AccountDeletableStatus _self;
  final $Res Function(AccountDeletableStatus) _then;

/// Create a copy of AccountDeletableStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deletable = null,Object? reasons = null,}) {
  return _then(_self.copyWith(
deletable: null == deletable ? _self.deletable : deletable // ignore: cast_nullable_to_non_nullable
as bool,reasons: null == reasons ? _self.reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountDeletableStatus].
extension AccountDeletableStatusPatterns on AccountDeletableStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountDeletableStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountDeletableStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountDeletableStatus value)  $default,){
final _that = this;
switch (_that) {
case _AccountDeletableStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountDeletableStatus value)?  $default,){
final _that = this;
switch (_that) {
case _AccountDeletableStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool deletable,  List<String> reasons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountDeletableStatus() when $default != null:
return $default(_that.deletable,_that.reasons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool deletable,  List<String> reasons)  $default,) {final _that = this;
switch (_that) {
case _AccountDeletableStatus():
return $default(_that.deletable,_that.reasons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool deletable,  List<String> reasons)?  $default,) {final _that = this;
switch (_that) {
case _AccountDeletableStatus() when $default != null:
return $default(_that.deletable,_that.reasons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountDeletableStatus implements AccountDeletableStatus {
  const _AccountDeletableStatus({required this.deletable, final  List<String> reasons = const []}): _reasons = reasons;
  factory _AccountDeletableStatus.fromJson(Map<String, dynamic> json) => _$AccountDeletableStatusFromJson(json);

@override final  bool deletable;
 final  List<String> _reasons;
@override@JsonKey() List<String> get reasons {
  if (_reasons is EqualUnmodifiableListView) return _reasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reasons);
}


/// Create a copy of AccountDeletableStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountDeletableStatusCopyWith<_AccountDeletableStatus> get copyWith => __$AccountDeletableStatusCopyWithImpl<_AccountDeletableStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountDeletableStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountDeletableStatus&&(identical(other.deletable, deletable) || other.deletable == deletable)&&const DeepCollectionEquality().equals(other._reasons, _reasons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deletable,const DeepCollectionEquality().hash(_reasons));

@override
String toString() {
  return 'AccountDeletableStatus(deletable: $deletable, reasons: $reasons)';
}


}

/// @nodoc
abstract mixin class _$AccountDeletableStatusCopyWith<$Res> implements $AccountDeletableStatusCopyWith<$Res> {
  factory _$AccountDeletableStatusCopyWith(_AccountDeletableStatus value, $Res Function(_AccountDeletableStatus) _then) = __$AccountDeletableStatusCopyWithImpl;
@override @useResult
$Res call({
 bool deletable, List<String> reasons
});




}
/// @nodoc
class __$AccountDeletableStatusCopyWithImpl<$Res>
    implements _$AccountDeletableStatusCopyWith<$Res> {
  __$AccountDeletableStatusCopyWithImpl(this._self, this._then);

  final _AccountDeletableStatus _self;
  final $Res Function(_AccountDeletableStatus) _then;

/// Create a copy of AccountDeletableStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deletable = null,Object? reasons = null,}) {
  return _then(_AccountDeletableStatus(
deletable: null == deletable ? _self.deletable : deletable // ignore: cast_nullable_to_non_nullable
as bool,reasons: null == reasons ? _self._reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
