// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referee_blocked_date.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RefereeBlockedDate {

 String get id; DateTime get startDate; DateTime get endDate; String? get reason;
/// Create a copy of RefereeBlockedDate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefereeBlockedDateCopyWith<RefereeBlockedDate> get copyWith => _$RefereeBlockedDateCopyWithImpl<RefereeBlockedDate>(this as RefereeBlockedDate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefereeBlockedDate&&(identical(other.id, id) || other.id == id)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,id,startDate,endDate,reason);

@override
String toString() {
  return 'RefereeBlockedDate(id: $id, startDate: $startDate, endDate: $endDate, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $RefereeBlockedDateCopyWith<$Res>  {
  factory $RefereeBlockedDateCopyWith(RefereeBlockedDate value, $Res Function(RefereeBlockedDate) _then) = _$RefereeBlockedDateCopyWithImpl;
@useResult
$Res call({
 String id, DateTime startDate, DateTime endDate, String? reason
});




}
/// @nodoc
class _$RefereeBlockedDateCopyWithImpl<$Res>
    implements $RefereeBlockedDateCopyWith<$Res> {
  _$RefereeBlockedDateCopyWithImpl(this._self, this._then);

  final RefereeBlockedDate _self;
  final $Res Function(RefereeBlockedDate) _then;

/// Create a copy of RefereeBlockedDate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? startDate = null,Object? endDate = null,Object? reason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RefereeBlockedDate].
extension RefereeBlockedDatePatterns on RefereeBlockedDate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefereeBlockedDate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefereeBlockedDate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefereeBlockedDate value)  $default,){
final _that = this;
switch (_that) {
case _RefereeBlockedDate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefereeBlockedDate value)?  $default,){
final _that = this;
switch (_that) {
case _RefereeBlockedDate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime startDate,  DateTime endDate,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefereeBlockedDate() when $default != null:
return $default(_that.id,_that.startDate,_that.endDate,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime startDate,  DateTime endDate,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _RefereeBlockedDate():
return $default(_that.id,_that.startDate,_that.endDate,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime startDate,  DateTime endDate,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _RefereeBlockedDate() when $default != null:
return $default(_that.id,_that.startDate,_that.endDate,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class _RefereeBlockedDate implements RefereeBlockedDate {
  const _RefereeBlockedDate({required this.id, required this.startDate, required this.endDate, this.reason});
  

@override final  String id;
@override final  DateTime startDate;
@override final  DateTime endDate;
@override final  String? reason;

/// Create a copy of RefereeBlockedDate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefereeBlockedDateCopyWith<_RefereeBlockedDate> get copyWith => __$RefereeBlockedDateCopyWithImpl<_RefereeBlockedDate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefereeBlockedDate&&(identical(other.id, id) || other.id == id)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,id,startDate,endDate,reason);

@override
String toString() {
  return 'RefereeBlockedDate(id: $id, startDate: $startDate, endDate: $endDate, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$RefereeBlockedDateCopyWith<$Res> implements $RefereeBlockedDateCopyWith<$Res> {
  factory _$RefereeBlockedDateCopyWith(_RefereeBlockedDate value, $Res Function(_RefereeBlockedDate) _then) = __$RefereeBlockedDateCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime startDate, DateTime endDate, String? reason
});




}
/// @nodoc
class __$RefereeBlockedDateCopyWithImpl<$Res>
    implements _$RefereeBlockedDateCopyWith<$Res> {
  __$RefereeBlockedDateCopyWithImpl(this._self, this._then);

  final _RefereeBlockedDate _self;
  final $Res Function(_RefereeBlockedDate) _then;

/// Create a copy of RefereeBlockedDate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? startDate = null,Object? endDate = null,Object? reason = freezed,}) {
  return _then(_RefereeBlockedDate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
