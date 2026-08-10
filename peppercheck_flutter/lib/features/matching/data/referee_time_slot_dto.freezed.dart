// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referee_time_slot_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RefereeTimeSlotDto {

 String get id; int get dow; int get startMin; int get endMin; bool get isActive;
/// Create a copy of RefereeTimeSlotDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefereeTimeSlotDtoCopyWith<RefereeTimeSlotDto> get copyWith => _$RefereeTimeSlotDtoCopyWithImpl<RefereeTimeSlotDto>(this as RefereeTimeSlotDto, _$identity);

  /// Serializes this RefereeTimeSlotDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefereeTimeSlotDto&&(identical(other.id, id) || other.id == id)&&(identical(other.dow, dow) || other.dow == dow)&&(identical(other.startMin, startMin) || other.startMin == startMin)&&(identical(other.endMin, endMin) || other.endMin == endMin)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,dow,startMin,endMin,isActive);

@override
String toString() {
  return 'RefereeTimeSlotDto(id: $id, dow: $dow, startMin: $startMin, endMin: $endMin, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $RefereeTimeSlotDtoCopyWith<$Res>  {
  factory $RefereeTimeSlotDtoCopyWith(RefereeTimeSlotDto value, $Res Function(RefereeTimeSlotDto) _then) = _$RefereeTimeSlotDtoCopyWithImpl;
@useResult
$Res call({
 String id, int dow, int startMin, int endMin, bool isActive
});




}
/// @nodoc
class _$RefereeTimeSlotDtoCopyWithImpl<$Res>
    implements $RefereeTimeSlotDtoCopyWith<$Res> {
  _$RefereeTimeSlotDtoCopyWithImpl(this._self, this._then);

  final RefereeTimeSlotDto _self;
  final $Res Function(RefereeTimeSlotDto) _then;

/// Create a copy of RefereeTimeSlotDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? dow = null,Object? startMin = null,Object? endMin = null,Object? isActive = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,dow: null == dow ? _self.dow : dow // ignore: cast_nullable_to_non_nullable
as int,startMin: null == startMin ? _self.startMin : startMin // ignore: cast_nullable_to_non_nullable
as int,endMin: null == endMin ? _self.endMin : endMin // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RefereeTimeSlotDto].
extension RefereeTimeSlotDtoPatterns on RefereeTimeSlotDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefereeTimeSlotDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefereeTimeSlotDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefereeTimeSlotDto value)  $default,){
final _that = this;
switch (_that) {
case _RefereeTimeSlotDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefereeTimeSlotDto value)?  $default,){
final _that = this;
switch (_that) {
case _RefereeTimeSlotDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int dow,  int startMin,  int endMin,  bool isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefereeTimeSlotDto() when $default != null:
return $default(_that.id,_that.dow,_that.startMin,_that.endMin,_that.isActive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int dow,  int startMin,  int endMin,  bool isActive)  $default,) {final _that = this;
switch (_that) {
case _RefereeTimeSlotDto():
return $default(_that.id,_that.dow,_that.startMin,_that.endMin,_that.isActive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int dow,  int startMin,  int endMin,  bool isActive)?  $default,) {final _that = this;
switch (_that) {
case _RefereeTimeSlotDto() when $default != null:
return $default(_that.id,_that.dow,_that.startMin,_that.endMin,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefereeTimeSlotDto extends RefereeTimeSlotDto {
  const _RefereeTimeSlotDto({required this.id, required this.dow, required this.startMin, required this.endMin, required this.isActive}): super._();
  factory _RefereeTimeSlotDto.fromJson(Map<String, dynamic> json) => _$RefereeTimeSlotDtoFromJson(json);

@override final  String id;
@override final  int dow;
@override final  int startMin;
@override final  int endMin;
@override final  bool isActive;

/// Create a copy of RefereeTimeSlotDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefereeTimeSlotDtoCopyWith<_RefereeTimeSlotDto> get copyWith => __$RefereeTimeSlotDtoCopyWithImpl<_RefereeTimeSlotDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefereeTimeSlotDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefereeTimeSlotDto&&(identical(other.id, id) || other.id == id)&&(identical(other.dow, dow) || other.dow == dow)&&(identical(other.startMin, startMin) || other.startMin == startMin)&&(identical(other.endMin, endMin) || other.endMin == endMin)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,dow,startMin,endMin,isActive);

@override
String toString() {
  return 'RefereeTimeSlotDto(id: $id, dow: $dow, startMin: $startMin, endMin: $endMin, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$RefereeTimeSlotDtoCopyWith<$Res> implements $RefereeTimeSlotDtoCopyWith<$Res> {
  factory _$RefereeTimeSlotDtoCopyWith(_RefereeTimeSlotDto value, $Res Function(_RefereeTimeSlotDto) _then) = __$RefereeTimeSlotDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, int dow, int startMin, int endMin, bool isActive
});




}
/// @nodoc
class __$RefereeTimeSlotDtoCopyWithImpl<$Res>
    implements _$RefereeTimeSlotDtoCopyWith<$Res> {
  __$RefereeTimeSlotDtoCopyWithImpl(this._self, this._then);

  final _RefereeTimeSlotDto _self;
  final $Res Function(_RefereeTimeSlotDto) _then;

/// Create a copy of RefereeTimeSlotDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? dow = null,Object? startMin = null,Object? endMin = null,Object? isActive = null,}) {
  return _then(_RefereeTimeSlotDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,dow: null == dow ? _self.dow : dow // ignore: cast_nullable_to_non_nullable
as int,startMin: null == startMin ? _self.startMin : startMin // ignore: cast_nullable_to_non_nullable
as int,endMin: null == endMin ? _self.endMin : endMin // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
