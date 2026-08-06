// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referee_blocked_date_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RefereeBlockedDateDto {

 String get id; String get startDate; String get endDate; String? get reason;
/// Create a copy of RefereeBlockedDateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefereeBlockedDateDtoCopyWith<RefereeBlockedDateDto> get copyWith => _$RefereeBlockedDateDtoCopyWithImpl<RefereeBlockedDateDto>(this as RefereeBlockedDateDto, _$identity);

  /// Serializes this RefereeBlockedDateDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefereeBlockedDateDto&&(identical(other.id, id) || other.id == id)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,startDate,endDate,reason);

@override
String toString() {
  return 'RefereeBlockedDateDto(id: $id, startDate: $startDate, endDate: $endDate, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $RefereeBlockedDateDtoCopyWith<$Res>  {
  factory $RefereeBlockedDateDtoCopyWith(RefereeBlockedDateDto value, $Res Function(RefereeBlockedDateDto) _then) = _$RefereeBlockedDateDtoCopyWithImpl;
@useResult
$Res call({
 String id, String startDate, String endDate, String? reason
});




}
/// @nodoc
class _$RefereeBlockedDateDtoCopyWithImpl<$Res>
    implements $RefereeBlockedDateDtoCopyWith<$Res> {
  _$RefereeBlockedDateDtoCopyWithImpl(this._self, this._then);

  final RefereeBlockedDateDto _self;
  final $Res Function(RefereeBlockedDateDto) _then;

/// Create a copy of RefereeBlockedDateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? startDate = null,Object? endDate = null,Object? reason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RefereeBlockedDateDto].
extension RefereeBlockedDateDtoPatterns on RefereeBlockedDateDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefereeBlockedDateDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefereeBlockedDateDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefereeBlockedDateDto value)  $default,){
final _that = this;
switch (_that) {
case _RefereeBlockedDateDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefereeBlockedDateDto value)?  $default,){
final _that = this;
switch (_that) {
case _RefereeBlockedDateDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String startDate,  String endDate,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefereeBlockedDateDto() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String startDate,  String endDate,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _RefereeBlockedDateDto():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String startDate,  String endDate,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _RefereeBlockedDateDto() when $default != null:
return $default(_that.id,_that.startDate,_that.endDate,_that.reason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefereeBlockedDateDto extends RefereeBlockedDateDto {
  const _RefereeBlockedDateDto({required this.id, required this.startDate, required this.endDate, this.reason}): super._();
  factory _RefereeBlockedDateDto.fromJson(Map<String, dynamic> json) => _$RefereeBlockedDateDtoFromJson(json);

@override final  String id;
@override final  String startDate;
@override final  String endDate;
@override final  String? reason;

/// Create a copy of RefereeBlockedDateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefereeBlockedDateDtoCopyWith<_RefereeBlockedDateDto> get copyWith => __$RefereeBlockedDateDtoCopyWithImpl<_RefereeBlockedDateDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefereeBlockedDateDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefereeBlockedDateDto&&(identical(other.id, id) || other.id == id)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,startDate,endDate,reason);

@override
String toString() {
  return 'RefereeBlockedDateDto(id: $id, startDate: $startDate, endDate: $endDate, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$RefereeBlockedDateDtoCopyWith<$Res> implements $RefereeBlockedDateDtoCopyWith<$Res> {
  factory _$RefereeBlockedDateDtoCopyWith(_RefereeBlockedDateDto value, $Res Function(_RefereeBlockedDateDto) _then) = __$RefereeBlockedDateDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String startDate, String endDate, String? reason
});




}
/// @nodoc
class __$RefereeBlockedDateDtoCopyWithImpl<$Res>
    implements _$RefereeBlockedDateDtoCopyWith<$Res> {
  __$RefereeBlockedDateDtoCopyWithImpl(this._self, this._then);

  final _RefereeBlockedDateDto _self;
  final $Res Function(_RefereeBlockedDateDto) _then;

/// Create a copy of RefereeBlockedDateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? startDate = null,Object? endDate = null,Object? reason = freezed,}) {
  return _then(_RefereeBlockedDateDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
